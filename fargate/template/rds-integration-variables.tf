################################################################################
# Variáveis para integração RDS com container
################################################################################

variable "db_use_environment_variable" {
  description = "Passar credenciais do DB como variáveis de ambiente separadas (DB_HOST, DB_PORT, etc)"
  type        = bool
  default     = false
}

variable "db_connection_string_env_var_name" {
  description = "Nome da variável de ambiente para connection string completa"
  type        = string
  default     = "POSTGRES_DSN"
}

variable "db_password_env_var_name" {
  description = "Nome da variável de ambiente para senha do database"
  type        = string
  default     = "DB_PASSWORD"
}
