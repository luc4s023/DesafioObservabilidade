################################################################################
# RDS PostgreSQL
################################################################################

# Gerar senha aleatória para o RDS (será armazenada no Secrets Manager)
resource "random_password" "db_password" {
  count = var.create_rds ? 1 : 0

  length  = 32
  special = true
  # Evitar caracteres que podem causar problemas em connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Armazenar a senha no Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  count = var.create_rds ? 1 : 0

  name_prefix             = "${local.name_prefix}-db-password-"
  description             = "Senha do RDS PostgreSQL para ${local.name_prefix}"
  recovery_window_in_days = var.db_secret_recovery_window_days

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  count = var.create_rds ? 1 : 0

  secret_id     = aws_secretsmanager_secret.db_password[0].id
  secret_string = random_password.db_password[0].result
}

# Subnet Group para o RDS
resource "aws_db_subnet_group" "this" {
  count = var.create_rds ? 1 : 0

  name_prefix = "${local.name_prefix}-db-"
  description = "Subnet group para RDS ${local.name_prefix}"
  subnet_ids  = var.db_subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-db-subnet-group"
    }
  )
}

# Security Group do RDS
resource "aws_security_group" "rds" {
  count = var.create_rds ? 1 : 0

  name_prefix = "${local.name_prefix}-rds-"
  description = "Security group para RDS PostgreSQL ${local.name_prefix}"
  vpc_id      = var.vpc_id

  # Permite conexões do ECS na porta PostgreSQL
  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
    description     = "Allow PostgreSQL from ECS tasks"
  }

  # Permite conexões de IPs específicos (opcional - para administração)
  dynamic "ingress" {
    for_each = length(var.db_allowed_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = var.db_port
      to_port     = var.db_port
      protocol    = "tcp"
      cidr_blocks = var.db_allowed_cidr_blocks
      description = "Allow PostgreSQL from specific IPs"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-rds-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "this" {
  count = var.create_rds ? 1 : 0

  identifier_prefix = "${local.name_prefix}-"

  # Engine
  engine               = "postgres"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  storage_type         = var.db_storage_type
  storage_encrypted    = var.db_storage_encrypted
  kms_key_id           = var.db_kms_key_id
  max_allocated_storage = var.db_max_allocated_storage

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password[0].result
  port     = var.db_port

  # Network & Security
  db_subnet_group_name   = aws_db_subnet_group.this[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  publicly_accessible    = var.db_publicly_accessible

  # Backup & Maintenance
  backup_retention_period   = var.db_backup_retention_period
  backup_window             = var.db_backup_window
  maintenance_window        = var.db_maintenance_window
  enabled_cloudwatch_logs_exports = var.db_enabled_cloudwatch_logs_exports

  # Snapshot & Deletion
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.name_prefix}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection       = var.db_deletion_protection

  # Performance Insights
  performance_insights_enabled    = var.db_performance_insights_enabled
  performance_insights_retention_period = var.db_performance_insights_enabled ? var.db_performance_insights_retention : null

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.db_auto_minor_version_upgrade

  # Parâmetros adicionais
  parameter_group_name = var.db_parameter_group_name
  option_group_name    = var.db_option_group_name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-postgresql"
    }
  )

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier,
      password, # A senha é gerenciada pelo Secrets Manager
    ]
  }
}

################################################################################
# Connection String no Secrets Manager
################################################################################

# Criar a connection string completa
locals {
  db_connection_string = var.create_rds ? "postgres://${var.db_username}:${random_password.db_password[0].result}@${aws_db_instance.this[0].endpoint}/${var.db_name}?sslmode=${var.db_ssl_mode}" : ""
}

resource "aws_secretsmanager_secret" "db_connection_string" {
  count = var.create_rds ? 1 : 0

  name_prefix             = "${local.name_prefix}-db-connection-"
  description             = "Connection string completa do RDS PostgreSQL para ${local.name_prefix}"
  recovery_window_in_days = var.db_secret_recovery_window_days

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_connection_string" {
  count = var.create_rds ? 1 : 0

  secret_id     = aws_secretsmanager_secret.db_connection_string[0].id
  secret_string = local.db_connection_string
}

################################################################################
# Outputs do RDS
################################################################################

output "db_instance_endpoint" {
  description = "Endpoint do RDS PostgreSQL"
  value       = var.create_rds ? aws_db_instance.this[0].endpoint : null
}

output "db_instance_address" {
  description = "Endereço (hostname) do RDS PostgreSQL"
  value       = var.create_rds ? aws_db_instance.this[0].address : null
}

output "db_instance_name" {
  description = "Nome do database"
  value       = var.create_rds ? aws_db_instance.this[0].db_name : null
}

output "db_instance_username" {
  description = "Username do database"
  value       = var.create_rds ? aws_db_instance.this[0].username : null
  sensitive   = true
}

output "db_password_secret_arn" {
  description = "ARN do secret com a senha do database"
  value       = var.create_rds ? aws_secretsmanager_secret.db_password[0].arn : null
}

output "db_connection_string_secret_arn" {
  description = "ARN do secret com a connection string completa"
  value       = var.create_rds ? aws_secretsmanager_secret.db_connection_string[0].arn : null
}

output "db_security_group_id" {
  description = "ID do security group do RDS"
  value       = var.create_rds ? aws_security_group.rds[0].id : null
}

output "db_instance_id" {
  description = "ID da instância RDS"
  value       = var.create_rds ? aws_db_instance.this[0].id : null
}
