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


type User struct {
    ID           int64  `json:"id"`           
    Username     string `json:"username"`
    Email        string `json:"email"`
    PasswordHash string `json:"-"`            
}

type RegisterPayload struct {
    Username string `json:"username"`
    Email    string `json:"email"`
    Password string `json:"password"` 
}

var db *sql.DB

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

func HashPassword(password string) string {
    hash := sha256.Sum256([]byte(password))
    return hex.EncodeToString(hash[:])
}

func RegisterUser(username, email, password string) (User, error) {
    username = strings.TrimSpace(username)
    email = strings.TrimSpace(email)
    password = strings.TrimSpace(password)

    if username == "" {
        return User{}, errors.New("nome de utilizador não pode ser vazio")
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
            if pgErr.Code == "23505" { 
                switch pgErr.Constraint {
                case "users_username_key":
                    return User{}, fmt.Errorf("nome de utilizador '%s' já existe", username)
                case "users_email_key":
                    return User{}, fmt.Errorf("email '%s' já registado", email)
                default:
                    return User{}, fmt.Errorf("conflito de dados: %s (constraint: %s)", pgErr.Message, pgErr.Constraint)
                }
            }
        }
        return User{}, fmt.Errorf("erro ao inserir utilizador: %v", err)
    }

    newUser := User{
        ID:       userID,
        Username: username,
        Email:    email,
    }
    return newUser, nil
}

func GetUsersByUsernamePartial(username string) ([]User, error) {
    querySQL := "SELECT id, username, email FROM users WHERE username ILIKE $1 ORDER BY id"
    searchPattern := "%" + strings.ToLower(username) + "%" 

    rows, err := db.Query(querySQL, searchPattern)
    if err != nil {
        return nil, fmt.Errorf("erro ao buscar utilizadores por nome: %v", err)
    }
    defer rows.Close()

    var usersFound []User
    for rows.Next() {
        var u User
        if err := rows.Scan(&u.ID, &u.Username, &u.Email); err != nil {
            log.Printf("Erro ao escanear linha do utilizador durante busca parcial: %v\n", err)
            continue
        }
        usersFound = append(usersFound, u)
    }

    if err := rows.Err(); err != nil {
        return nil, fmt.Errorf("erro durante a iteração das linhas de utilizadores na busca parcial: %v", err)
    }
    return usersFound, nil
}

func getAllUsersFromDB() ([]User, error) {
    querySQL := "SELECT id, username, email FROM users ORDER BY id"
    rows, err := db.Query(querySQL)
    if err != nil {
        return nil, fmt.Errorf("erro ao buscar utilizadores: %v", err)
    }
    defer rows.Close()

    var usersFound []User
    for rows.Next() {
        var u User
        if err := rows.Scan(&u.ID, &u.Username, &u.Email); err != nil {
            log.Printf("Erro ao escanear linha do utilizador: %v\n", err)
            continue
        }
        usersFound = append(usersFound, u)
    }

    if err := rows.Err(); err != nil {
        return nil, fmt.Errorf("erro durante a iteração das linhas de utilizadores: %v", err)
    }
    return usersFound, nil
}

func DeleteUserByID(id int64) error {
    deleteSQL := "DELETE FROM users WHERE id = $1"

    result, err := db.Exec(deleteSQL, id)
    if err != nil {
        return fmt.Errorf("erro ao tentar eliminar utilizador com ID %d: %v", id, err)
    }

    rowsAffected, err := result.RowsAffected()
    if err != nil {
        return fmt.Errorf("erro ao verificar linhas afetadas após eliminar utilizador com ID %d: %v", id, err)
    }

    if rowsAffected == 0 {
        return fmt.Errorf("nenhum utilizador encontrado com ID %d para eliminar", id)
    }

    return nil
}



func enableCORS(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
        w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization")

        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }
        next(w, r)
    }
}

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
        if strings.Contains(err.Error(), "já existe") || strings.Contains(err.Error(), "já registado") {
            http.Error(w, err.Error(), http.StatusConflict) 
        } else if strings.Contains(err.Error(), "não pode ser vazio") || strings.Contains(err.Error(), "formato de email inválido") || strings.Contains(err.Error(), "senha deve ter") {
            http.Error(w, err.Error(), http.StatusBadRequest) 
        } else {
            http.Error(w, "Erro interno ao registar utilizador: "+err.Error(), http.StatusInternalServerError) 
        }
        return
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated) 
    json.NewEncoder(w).Encode(user)
}

func listUsersHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
        return
    }

    users, err := getAllUsersFromDB()
    if err != nil {
        http.Error(w, "Erro ao listar utilizadores: "+err.Error(), http.StatusInternalServerError)
        return
    }

    if users == nil {
        users = []User{}
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(users)
}

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

    users, err := GetUsersByUsernamePartial(username) 
    if err != nil {
        http.Error(w, "Erro ao buscar utilizadores: "+err.Error(), http.StatusInternalServerError)
        return
    }

    if len(users) == 0 {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode([]User{})
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(users) 
}


func deleteUserByIDHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodDelete {
        http.Error(w, "Método não permitido", http.StatusMethodNotAllowed)
        return
    }

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
        if strings.Contains(err.Error(), "nenhum utilizador encontrado") {
            http.Error(w, err.Error(), http.StatusNotFound) 
        } else {
            http.Error(w, "Erro ao eliminar utilizador: "+err.Error(), http.StatusInternalServerError) 
        }
        return
    }

    w.WriteHeader(http.StatusOK) 
    fmt.Fprintf(w, "Utilizador com ID %d eliminado com sucesso.", idToDelete)
}

func main() {
    pgDSN := os.Getenv("POSTGRES_DSN")
    if pgDSN == "" {
        fmt.Println("Variável de ambiente POSTGRES_DSN não definida. Usando DSN padrão para localhost.")
        pgDSN = "postgres://postgres:password@localhost:5432/user_registration_db?sslmode=disable"
        fmt.Printf("DSN Padrão: %s (ajuste conforme necessário)\n", pgDSN)
    }

    initDBPG(pgDSN)

    fs := http.FileServer(http.Dir("."))
    http.Handle("/", fs) 


    http.HandleFunc("/api/users/register", enableCORS(registerUserHandler))
    http.HandleFunc("/api/users", enableCORS(listUsersHandler))
    http.HandleFunc("/api/users/", enableCORS(deleteUserByIDHandler))
    http.HandleFunc("/api/user", enableCORS(getUserByUsernameHandler)) 

    port := "8080"
    fmt.Printf("Servidor escutando na porta %s...\n", port)
    fmt.Println("Endpoints disponíveis:")
    fmt.Println("  GET    / (Serve o index.html e outros ficheiros estáticos)")
    fmt.Println("  POST   /api/users/register")
    fmt.Println("  GET    /api/users")
    fmt.Println("  GET    /api/user?username=<nome>")
    fmt.Println("  DELETE /api/users/<id>")

    log.Fatal(http.ListenAndServe(":"+port, nil))
}
