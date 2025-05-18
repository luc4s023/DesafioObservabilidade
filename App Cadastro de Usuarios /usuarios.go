
package main

import (
	"bufio"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"github.com/lib/pq" 
)

type User struct {
	ID           int64
	Username     string
	Email        string
	PasswordHash string
}

var db *sql.DB

// initDBPG inicializa a conexão com o banco de dados PostgreSQL e cria a tabela se não existir.
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

// RegisterUser adiciona um novo usuário ao banco de dados PostgreSQL
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
			if pgErr.Code == "23505" { 
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
		ID:           userID,
		Username:     username,
		Email:        email,
		PasswordHash: passwordHash,
	}
	return newUser, nil
}

func GetUserByUsername(username string) (User, bool) {
	querySQL := "SELECT id, username, email, password_hash FROM users WHERE username = $1"
	row := db.QueryRow(querySQL, username)

	var user User
	err := row.Scan(&user.ID, &user.Username, &user.Email, &user.PasswordHash)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return User{}, false
		}
		log.Printf("Erro ao buscar usuário '%s': %v\n", username, err)
		return User{}, false
	}
	return user, true
}

func listAllUsers() {
	querySQL := "SELECT id, username, email, password_hash FROM users ORDER BY id"
	rows, err := db.Query(querySQL)
	if err != nil {
		fmt.Printf("Erro ao listar usuários: %v\n", err)
		return
	}
	defer rows.Close()

	var usersFound []User
	for rows.Next() {
		var u User
		if err := rows.Scan(&u.ID, &u.Username, &u.Email, &u.PasswordHash); err != nil {
			fmt.Printf("Erro ao escanear linha do usuário: %v\n", err)
			continue
		}
		usersFound = append(usersFound, u)
	}

	if err := rows.Err(); err != nil {
		fmt.Printf("Erro durante a iteração das linhas de usuários: %v\n", err)
		return
	}

	if len(usersFound) == 0 {
		fmt.Println("\nNenhum usuário cadastrado ainda.")
		return
	}

	fmt.Println("\n--- Usuários Cadastrados (PostgreSQL) ---")
	for _, u := range usersFound {
		hashPreview := u.PasswordHash
		if len(hashPreview) > 10 {
			hashPreview = hashPreview[:10] + "..."
		}
		fmt.Printf("ID: %d, Username: %s, Email: %s, PasswordHash (preview): %s\n", u.ID, u.Username, u.Email, hashPreview)
	}
	fmt.Println("---------------------------------------")
}

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

	fmt.Printf("Usuário com ID %d deletado com sucesso.\n", id)
	return nil
}


func main() {
	pgDSN := os.Getenv("POSTGRES_DSN")
	if pgDSN == "" {
		fmt.Println("Variável de ambiente POSTGRES_DSN não definida. Usando DSN padrão para localhost.")
		pgDSN = "postgres://postgres:password@localhost:5432/user_registration_db?sslmode=disable" // AJUSTE CONFORME NECESSÁRIO
		fmt.Printf("DSN Padrão: %s (ajuste conforme necessário)\n", pgDSN)
	}

	initDBPG(pgDSN)
	defer func() {
		if err := db.Close(); err != nil {
			log.Printf("Erro ao fechar o banco de dados: %v", err)
		}
		fmt.Println("Conexão com o banco de dados PostgreSQL fechada.")
	}()

	reader := bufio.NewReader(os.Stdin)

	fmt.Println("Sistema Interativo de Cadastro de Usuários com Banco de Dados PostgreSQL")
	fmt.Println("-----------------------------------------------------------------------")

	for {
		fmt.Println("\nEscolha uma opção:")
		fmt.Println("1. Criar novo usuario")
		fmt.Println("2. Listar todos os usuarios")
		fmt.Println("3. Buscar usuario por nome")
		fmt.Println("4. Deletar usuário por ID") 
		fmt.Println("5. Sair")                  

		fmt.Print("Digite sua escolha: ")

		choiceInput, _ := reader.ReadString('\n')
		choice := strings.TrimSpace(choiceInput)

		switch choice {
		case "1":
			fmt.Println("\n--- Cadastro de Novo Usuário ---")
			fmt.Print("Digite o nome de usuário: ")
			usernameInput, _ := reader.ReadString('\n')
			username := strings.TrimSpace(usernameInput)

			fmt.Print("Digite o email: ")
			emailInput, _ := reader.ReadString('\n')
			email := strings.TrimSpace(emailInput)

			fmt.Print("Digite a senha (mínimo 6 caracteres): ")
			passwordInput, _ := reader.ReadString('\n')
			password := strings.TrimSpace(passwordInput)

			user, err := RegisterUser(username, email, password)
			if err != nil {
				fmt.Printf("Erro ao registrar usuário: %v\n", err)
			} else {
				fmt.Printf("Usuário '%s' registrado com sucesso! ID: %d\n", user.Username, user.ID)
			}

		case "2":
			listAllUsers()

		case "3":
			fmt.Print("\nDigite o nome de usuário para buscar: ")
			searchInput, _ := reader.ReadString('\n')
			searchUsername := strings.TrimSpace(searchInput)

			user, found := GetUserByUsername(searchUsername)
			if found {
				fmt.Printf("Usuário encontrado: ID: %d, Username: %s, Email: %s\n", user.ID, user.Username, user.Email)
			} else {
				fmt.Printf("Usuário '%s' não encontrado.\n", searchUsername)
			}

		case "4": 
			fmt.Println("\n--- Deletar Usuário por ID ---")
			fmt.Print("Digite o ID do usuário a ser deletado: ")
			idInput, _ := reader.ReadString('\n')
			idStr := strings.TrimSpace(idInput)

			idToDelete, err := strconv.ParseInt(idStr, 10, 64)
			if err != nil {
				fmt.Printf("ID inválido: %v. Por favor, insira um número.\n", err)
				continue 
			}

			fmt.Printf("Tem certeza que deseja deletar o usuário com ID %d? (s/N): ", idToDelete)
			confirmInput, _ := reader.ReadString('\n')
			confirm := strings.TrimSpace(strings.ToLower(confirmInput))

			if confirm == "s" || confirm == "sim" {
				err = DeleteUserByID(idToDelete)
				if err != nil {
					fmt.Printf("Erro ao deletar usuário: %v\n", err)
				}
			} else {
				fmt.Println("Operação de deleção cancelada.")
			}


		case "5":
			fmt.Println("Saindo do sistema...")
			return

		default:
			fmt.Println("Opção inválida. Por favor, tente novamente.")
		}
	}
}
