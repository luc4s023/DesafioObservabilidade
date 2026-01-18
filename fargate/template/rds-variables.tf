################################################################################
# RDS Configuration
################################################################################

variable "create_rds" {
  description = "Criar instância RDS PostgreSQL"
  type        = bool
  default     = false
}

variable "db_subnet_ids" {
  description = "IDs das subnets para o RDS (devem ser subnets privadas)"
  type        = list(string)
  default     = []
}

variable "db_name" {
  description = "Nome do database a ser criado"
  type        = string
  default     = "cadastro_user_db"
}

variable "db_username" {
  description = "Username master do database"
  type        = string
  default     = "postgres"
}

variable "db_port" {
  description = "Porta do PostgreSQL"
  type        = number
  default     = 5432
}

variable "db_engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "16.1" # Versão compatível mais recente
}

variable "db_instance_class" {
  description = "Classe da instância RDS (ex: db.t3.micro, db.t4g.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage alocado em GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Storage máximo para autoscaling (0 = desabilitado)"
  type        = number
  default     = 100
}

variable "db_storage_type" {
  description = "Tipo de storage (gp2, gp3, io1)"
  type        = string
  default     = "gp3"
}

variable "db_storage_encrypted" {
  description = "Habilitar encriptação do storage"
  type        = bool
  default     = true
}

variable "db_kms_key_id" {
  description = "ARN da KMS key para encriptação (null = usa chave padrão)"
  type        = string
  default     = null
}

variable "db_publicly_accessible" {
  description = "Tornar o RDS publicamente acessível (NÃO recomendado para produção)"
  type        = bool
  default     = false
}

variable "db_backup_retention_period" {
  description = "Dias de retenção dos backups automáticos (0 = desabilitado)"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Janela de backup (formato: HH:MM-HH:MM UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Janela de manutenção (formato: ddd:HH:MM-ddd:HH:MM UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "db_skip_final_snapshot" {
  description = "Pular snapshot final ao deletar (use true apenas em dev/test)"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Habilitar proteção contra deleção"
  type        = bool
  default     = true
}

variable "db_performance_insights_enabled" {
  description = "Habilitar Performance Insights"
  type        = bool
  default     = false
}

variable "db_performance_insights_retention" {
  description = "Dias de retenção do Performance Insights"
  type        = number
  default     = 7
}

variable "db_enabled_cloudwatch_logs_exports" {
  description = "Tipos de logs para exportar para CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "db_auto_minor_version_upgrade" {
  description = "Habilitar auto upgrade de versões minor"
  type        = bool
  default     = true
}

variable "db_parameter_group_name" {
  description = "Nome do parameter group customizado (null = usa padrão)"
  type        = string
  default     = null
}

variable "db_option_group_name" {
  description = "Nome do option group customizado (null = usa padrão)"
  type        = string
  default     = null
}

variable "db_allowed_cidr_blocks" {
  description = "CIDRs permitidos para acessar o RDS (útil para bastion host)"
  type        = list(string)
  default     = []
}

variable "db_ssl_mode" {
  description = "Modo SSL da connection string (disable, require, verify-ca, verify-full)"
  type        = string
  default     = "require"
}

variable "db_secret_recovery_window_days" {
  description = "Dias de recovery window para secrets deletados"
  type        = number
  default     = 7
}
