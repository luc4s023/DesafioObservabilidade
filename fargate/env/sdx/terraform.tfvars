################################################################################
# Configuração SDX - ECS Fargate com RDS PostgreSQL
################################################################################

# General
aws_region   = "us-east-1"
environment  = "sdx"
project_name = "golang-usuarios"
app_name     = "cadastro-usuarios"

################################################################################
# Network - AJUSTE com seus IDs reais de VPC e Subnets
################################################################################

vpc_id = "vpc-0ff4d81d5971fd0f3"

# Subnets PRIVADAS para ECS tasks e RDS (precisam estar em AZs diferentes)
private_subnet_ids = ["subnet-02311fcc54c413812", "subnet-097443b50e3facbc5"]

# Subnets PÚBLICAS para ALB
public_subnet_ids = ["subnet-public1", "subnet-public2"]

assign_public_ip = false

################################################################################
# Container - Imagem do ECR
################################################################################

container_image = "349110610245.dkr.ecr.us-east-1.amazonaws.com/golang-project/cadastro-usuarios:latest"
container_port  = 8080

# Variáveis de ambiente da aplicação
# NOTA: POSTGRES_DSN será injetado automaticamente pelo RDS
container_environment = [
  {
    name  = "APP_ENV"
    value = "development"
  },
  {
    name  = "PORT"
    value = "8080"
  },
  {
    name  = "LOG_LEVEL"
    value = "debug"
  }
]

# Secrets adicionais (se necessário)
container_secrets = []

################################################################################
# RDS PostgreSQL - Habilitar e configurar
################################################################################

create_rds = true

# Subnets para o RDS (DEVEM ser privadas e em AZs diferentes)
# Pode ser as mesmas do ECS ou subnets dedicadas
db_subnet_ids = ["subnet-private1", "subnet-private2"]

# Database
db_name     = "cadastro_user_db"
db_username = "postgres"
db_port     = 5432

# Versão do PostgreSQL (compatível com postgres:18 do docker-compose)
db_engine_version = "16.1" # Versão mais recente disponível no RDS

# Tamanho da instância (Free tier elegível)
db_instance_class = "db.t3.micro"

# Storage
db_allocated_storage     = 20    # GB inicial
db_max_allocated_storage = 100   # GB máximo (autoscaling)
db_storage_type          = "gp3" # Mais econômico que gp2
db_storage_encrypted     = true

# Backup e Manutenção
db_backup_retention_period = 7                     # 7 dias de backup
db_backup_window           = "03:00-04:00"         # UTC (00:00-01:00 BRT)
db_maintenance_window      = "sun:04:00-sun:05:00" # UTC (Dom 01:00-02:00 BRT)

# Segurança
db_publicly_accessible = false # Acesso apenas via VPC
db_deletion_protection = false # true em produção
db_skip_final_snapshot = true  # false em produção (criar snapshot antes de deletar)

# Performance Insights (opcional, custo adicional)
db_performance_insights_enabled = false # true em produção

# SSL/TLS (compatível com docker-compose que usa sslmode=disable)
db_ssl_mode = "require" # require, verify-ca, verify-full, disable

# Logs exportados para CloudWatch
db_enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

# Auto minor version upgrade
db_auto_minor_version_upgrade = true

# IPs permitidos para acessar RDS (opcional - para bastion host ou debug)
# Exemplo: ["10.0.0.0/24"] para acesso de bastion na subnet 10.0.0.0/24
db_allowed_cidr_blocks = []

################################################################################
# Integração RDS com Container
################################################################################

# Nome da variável de ambiente que receberá a connection string completa
# Sua aplicação Go deve ler: os.Getenv("POSTGRES_DSN")
db_connection_string_env_var_name = "POSTGRES_DSN"

# Nome da variável para senha separada (se necessário)
db_password_env_var_name = "DB_PASSWORD"

# Se true, passa DB_HOST, DB_PORT, DB_NAME, DB_USER como variáveis separadas
# Se false (padrão), passa apenas POSTGRES_DSN com connection string completa
db_use_environment_variable = false

################################################################################
# Task Configuration
################################################################################

task_cpu      = 256
task_memory   = 512
desired_count = 2

################################################################################
# Health Check
################################################################################

enable_health_check      = true
health_check_command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
health_check_interval    = 30
health_check_timeout     = 5
health_check_retries     = 3
health_check_start_period = 60

################################################################################
# Load Balancer
################################################################################

enable_load_balancer              = true
alb_internal                      = false
alb_ingress_cidr_blocks          = ["0.0.0.0/0"]
enable_deletion_protection        = false
health_check_grace_period_seconds = 60

# Target Group Health Check
target_health_check_path               = "/health"
target_health_check_matcher            = "200"
target_health_check_interval           = 30
target_health_check_timeout            = 5
target_health_check_healthy_threshold  = 2
target_health_check_unhealthy_threshold = 3
target_deregistration_delay            = 30

################################################################################
# Auto Scaling
################################################################################

enable_autoscaling        = true
autoscaling_min_capacity  = 2
autoscaling_max_capacity  = 10
autoscaling_cpu_target    = 70
autoscaling_memory_target = 80

################################################################################
# Deployment
################################################################################

deployment_maximum_percent         = 200
deployment_minimum_healthy_percent = 100
force_new_deployment               = false

################################################################################
# Monitoring
################################################################################

enable_container_insights = true
log_retention_days       = 7

################################################################################
# Debug
################################################################################

enable_ecs_exec = true
