package main

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	"github.com/lib/pq"
)

// User representa a estrutura de um usuário no banco de dados.
type User struct {
	ID           int64  `json:"id"`           // Tags JSON para serialização
	Username     string `json:"username"`
	Email        string `json:"email"`
	PasswordHash string `json:"-"`            // Use '-' para omitir este campo ao serializar para JSON por segurança
}

// RegisterPayload é usado para o corpo da requisição de registro,
// recebendo a senha em texto plano do frontend.
type RegisterPayload struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"` // CORRIGIDO: Agora espera "password" do frontend
}

var db *sql.DB

// initDBPG inicializa a conexão com o banco de dados PostgreSQL e cria a tabela 'users' se ela não existir.
func initDBPG(dataSourceName string) {
	var err error
	db, err = sql.Open("postgres", dataSourceName)
	if err != nil {
		log.Fatalf("Erro ao tentar abrir a conexão com o banco de dados: %v", err)
	}

	if err = db.Ping(); err != nil {
		db.Close()
		log.Fatalf("Erro ao conectar ao banco de dados (Ping falhou): %v\nVerifique sua string de conexão e se o servidor PostgreSQL está acessível.", err)
	}

	createTableSQL := `
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL
    );`

	_, err = db.Exec(createTableSQL)
	if err != nil {
		db.Close()
		log.Fatalf("Erro ao criar a tabela 'users': %v", err)
	}

	fmt.Println("Banco de dados PostgreSQL conectado e tabela 'users' pronta.")
}

// HashPassword gera um hash SHA256 da senha fornecida.
func HashPassword(password string) string {
	hash := sha256.Sum256([]byte(password))
	return hex.EncodeToString(hash[:])
}

// RegisterUser insere um novo usuário no banco de dados.
// Realiza validações básicas e trata erros de duplicidade.
func RegisterUser(username, email, password string) (User, error) {
	username = strings.TrimSpace(username)
	email = strings.TrimSpace(email)
	password = strings.TrimSpace(password)

	if username == "" {
		return User{}, errors.New("nome de usuário não pode ser vazio")
	}
	if email == "" {
		return User{}, errors.New("email não pode ser vazio")
	}
	if !strings.Contains(email, "@") {
		return User{}, errors.New("formato de email inválido")
	}
	if password == "" {
		return User{}, errors.New("senha não pode ser vazia")
	}
	if len(password) < 6 {
		return User{}, errors.New("senha deve ter pelo menos 6 caracteres")
	}

	passwordHash := HashPassword(password)
	insertSQL := "INSERT INTO users(username, email, password_hash) VALUES ($1, $2, $3) RETURNING id"
	var userID int64

	err := db.QueryRow(insertSQL, username, email, passwordHash).Scan(&userID)
	if err != nil {
		if pgErr, ok := err.(*pq.Error); ok {
			if pgErr.Code == "23505" { // Código de erro para violação de unique constraint
				switch pgErr.Constraint {
				case "users_username_key":
					return User{}, fmt.Errorf("nome de usuário '%s' já existe", username)
				case "users_email_key":
					return User{}, fmt.Errorf("email '%s' já cadastrado", email)
				default:
					return User{}, fmt.Errorf("conflito de dados: %s (constraint: %s)", pgErr.Message, pgErr.Constraint)
				}
			}
		}
		return User{}, fmt.Errorf("erro ao inserir usuário: %v", err)
	}

	newUser := User{
		ID:       userID,
		Username: username,
		Email:    email,
		// PasswordHash é omitido no JSON de resposta devido à tag `json:"-"`
	}
	return newUser, nil
}

// GetUsersByUsernamePartial busca usuários pelo nome de usuário, permitindo busca parcial e insensível a maiúsculas/minúsculas.
// Retorna uma slice de usuários encontrados.
func GetUsersByUsernamePartial(username string) ([]User, error) {
	// Usamos ILIKE para busca insensível a maiúsculas/minúsculas e % para busca parcial.
	querySQL := "SELECT id, username, email FROM users WHERE username ILIKE $1 ORDER BY id"
	// Adiciona wildcards para busca parcial
	searchPattern := "%" + strings.ToLower(username) + "%" // Converte para minúsculas para garantir a insensibilidade antes de adicionar wildcards

	rows, err := db.Query(querySQL, searchPattern)
	if err != nil {
		return nil, fmt.Errorf("erro ao buscar usuários por nome: %v", err)
	}
	defer rows.Close()

	var usersFound []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Username, &u.Email); err != nil {
			log.Printf("Erro ao escanear linha do usuário durante busca parcial: %v\n", err)
			continue
		}
		usersFound = append(usersFound, u)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("erro durante a iteração das linhas de usuários na busca parcial: %v", err)
	}
	return usersFound, nil
}

// getAllUsersFromDB busca todos os usuários do banco de dados.
// Não inclui o hash da senha por segurança.
func getAllUsersFromDB() ([]User, error) {
	querySQL := "SELECT id, username, email FROM users ORDER BY id"
	rows, err := db.Query(querySQL)
	if err != nil {
		return nil, fmt.Errorf("erro ao buscar usuários: %v", err)
	}
	defer rows.Close()

	var usersFound []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Username, &u.Email); err != nil {
			log.Printf("Erro ao escanear linha do usuário: %v\n", err)
			continue
		}
		usersFound = append(usersFound, u)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("erro durante a iteração das linhas de usuários: %v", err)
	}
	return usersFound, nil
}

// DeleteUserByID deleta um usuário do banco de dados pelo seu ID.
func DeleteUserByID(id int64) error {
	deleteSQL := "DELETE FROM users WHERE id = $1"

	result, err := db.Exec(deleteSQL, id)
	if err != nil {
		return fmt.Errorf("erro ao tentar deletar usuário com ID %d: %v", id, err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("erro ao verificar linhas afetadas após deletar usuário com ID %d: %v", id, err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("nenhum usuário encontrado com ID %d para deletar", id)
	}

	return nil
}

// --- HTTP Handlers ---

// enableCORS middleware para adicionar headers CORS e lidar com requisições OPTIONS.
func enableCORS(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Permite qualquer origem (para desenvolvimento). Em produção, especifique origens seguras.
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization")

		// Se for uma requisição OPTIONS (preflight), apenas retorne os headers e status OK.
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next(w, r) // Chama o próximo handler
	}
}

// registerUserHandler lida com requisições POST para registrar novos usuários.
func registerUserHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	var payload RegisterPayload
	err := json.NewDecoder(r.Body).Decode(&payload)
	if err != nil {
		http.Error(w, "Corpo da requisição inválido: "+err.Error(), http.StatusBadRequest)
		return
	}

	user, err := RegisterUser(payload.Username, payload.Email, payload.Password)
	if err != nil {
		if strings.Contains(err.Error(), "já existe") || strings.Contains(err.Error(), "já cadastrado") {
			http.Error(w, err.Error(), http.StatusConflict) // 409 Conflict
		} else if strings.Contains(err.Error(), "não pode ser vazio") || strings.Contains(err.Error(), "formato de email inválido") || strings.Contains(err.Error(), "senha deve ter") {
			http.Error(w, err.Error(), http.StatusBadRequest) // 400 Bad Request
		} else {
			http.Error(w, "Erro interno ao registrar usuário: "+err.Error(), http.StatusInternalServerError) // 500 Internal Server Error
		}
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated) // 201 Created
	json.NewEncoder(w).Encode(user)
}

// listUsersHandler lida com requisições GET para listar todos os usuários.
func listUsersHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	users, err := getAllUsersFromDB()
	if err != nil {
		http.Error(w, "Erro ao listar usuários: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Se não houver usuários, retorna uma lista vazia, não um erro.
	if users == nil {
		users = []User{}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

// getUserByUsernameHandler lida com requisições GET para buscar um usuário por nome de usuário.
// Agora busca por termos parciais e é insensível a maiúsculas/minúsculas.
func getUserByUsernameHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	username := r.URL.Query().Get("username")
	if username == "" {
		http.Error(w, "Parâmetro 'username' é obrigatório", http.StatusBadRequest)
		return
	}

	users, err := GetUsersByUsernamePartial(username) // Chama a nova função
	if err != nil {
		http.Error(w, "Erro ao buscar usuários: "+err.Error(), http.StatusInternalServerError)
		return
	}

	if len(users) == 0 {
		// Retorna um array vazio se nenhum usuário for encontrado
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK) // Status 200 OK, mas com array vazio
		json.NewEncoder(w).Encode([]User{})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users) // Retorna a lista de usuários encontrados
}

// deleteUserByIDHandler lida com requisições DELETE para deletar um usuário por ID.
// Espera o ID na URL, ex: /api/users/123
func deleteUserByIDHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
		return
	}

	// Extrai o ID da URL. Ex: /api/users/123 -> "123"
	// Remove o prefixo "/api/users/" e assume que o restante é o ID.
	idStr := strings.TrimPrefix(r.URL.Path, "/api/users/")
	if idStr == "" {
		http.Error(w, "URL inválida. Formato esperado: /api/users/{id}", http.StatusBadRequest)
		return
	}

	idToDelete, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "ID inválido: "+err.Error(), http.StatusBadRequest)
		return
	}

	err = DeleteUserByID(idToDelete)
	if err != nil {
		if strings.Contains(err.Error(), "nenhum usuário encontrado") {
			http.Error(w, err.Error(), http.StatusNotFound) // 404 Not Found
		} else {
			http.Error(w, "Erro ao deletar usuário: "+err.Error(), http.StatusInternalServerError) // 500 Internal Server Error
		}
		return
	}

	w.WriteHeader(http.StatusOK) // 200 OK
	fmt.Fprintf(w, "Usuário com ID %d deletado com sucesso.", idToDelete)
}

func main() {
	pgDSN := os.Getenv("POSTGRES_DSN")
	if pgDSN == "" {
		fmt.Println("Variável de ambiente POSTGRES_DSN não definida. Usando DSN padrão para localhost.")
		// AJUSTE ESTA STRING DE CONEXÃO CONFORME SEU AMBIENTE
		pgDSN = "postgres://postgres:password@localhost:5432/user_registration_db?sslmode=disable"
		fmt.Printf("DSN Padrão: %s (ajuste conforme necessário)\n", pgDSN)
	}

	initDBPG(pgDSN)

	// Definindo as rotas da API com o prefixo /api
	http.HandleFunc("/api/users/register", enableCORS(registerUserHandler))
	http.HandleFunc("/api/users", enableCORS(listUsersHandler))
	http.HandleFunc("/api/users/", enableCORS(deleteUserByIDHandler)) // Rota para DELETE espera /api/users/{id}
	http.HandleFunc("/api/user", enableCORS(getUserByUsernameHandler)) // GET com ?username=... (agora busca parcial)

	port := "8080"
	fmt.Printf("Servidor escutando na porta %s...\n", port)
	fmt.Println("Endpoints disponíveis:")
	fmt.Println("  POST   /api/users/register")
	fmt.Println("  GET    /api/users")
	fmt.Println("  GET    /api/user?username=<nome>") // Agora aceita busca parcial e insensível a maiúsculas/minúsculas
	fmt.Println("  DELETE /api/users/<id>")

	log.Fatal(http.ListenAndServe(":"+port, nil))
}
