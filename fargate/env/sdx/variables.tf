################################################################################
# General
################################################################################

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nome do ambiente (dev, sdx, stg, prd)"
  type        = string
  validation {
    condition     = contains(["dev", "sdx", "stg", "prd"], var.environment)
    error_message = "Environment deve ser: dev, sdx, stg ou prd"
  }
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "meu-projeto"
}

variable "app_name" {
  description = "Nome da aplicação"
  type        = string
}

variable "ecs_modules_path" {
  description = "Caminho para os módulos ECS (se diferente do padrão)"
  type        = string
  default     = null
}

################################################################################
# Network
################################################################################

variable "vpc_id" {
  description = "ID da VPC onde os recursos serão criados"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas para as tasks ECS"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "IDs das subnets públicas para o ALB"
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Atribuir IP público às tasks (necessário se usar subnets públicas sem NAT)"
  type        = bool
  default     = false
}

################################################################################
# Container Configuration
################################################################################

variable "container_image" {
  description = "Imagem Docker da aplicação (ex: nginx:latest ou ECR URL)"
  type        = string
}

variable "container_port" {
  description = "Porta que o container expõe"
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "CPU do container (null para usar CPU da task)"
  type        = number
  default     = null
}

variable "container_memory" {
  description = "Memória do container em MB (null para usar memória da task)"
  type        = number
  default     = null
}

variable "container_environment" {
  description = "Variáveis de ambiente para o container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "container_secrets" {
  description = "Secrets do AWS Secrets Manager ou Parameter Store"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

################################################################################
# Task Configuration
################################################################################

variable "task_cpu" {
  description = "CPU da task em unidades (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memória da task em MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Número desejado de tasks rodando"
  type        = number
  default     = 1
}

################################################################################
# Health Check
################################################################################

variable "enable_health_check" {
  description = "Habilitar health check do container"
  type        = bool
  default     = true
}

variable "health_check_command" {
  description = "Comando de health check do container"
  type        = list(string)
  default     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
}

variable "health_check_interval" {
  description = "Intervalo entre health checks (segundos)"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Timeout do health check (segundos)"
  type        = number
  default     = 5
}

variable "health_check_retries" {
  description = "Número de tentativas do health check"
  type        = number
  default     = 3
}

variable "health_check_start_period" {
  description = "Período de graça inicial do health check (segundos)"
  type        = number
  default     = 60
}

variable "health_check_grace_period_seconds" {
  description = "Período de graça do ALB health check após iniciar task"
  type        = number
  default     = 60
}

################################################################################
# Load Balancer
################################################################################

variable "enable_load_balancer" {
  description = "Habilitar Application Load Balancer"
  type        = bool
  default     = false
}

variable "alb_internal" {
  description = "Se true, o ALB será interno (privado)"
  type        = bool
  default     = false
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDRs permitidos para acessar o ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  description = "Habilitar proteção contra exclusão do ALB"
  type        = bool
  default     = false
}

variable "target_health_check_path" {
  description = "Path do health check do target group"
  type        = string
  default     = "/health"
}

variable "target_health_check_matcher" {
  description = "Código HTTP de sucesso do health check"
  type        = string
  default     = "200"
}

variable "target_health_check_interval" {
  description = "Intervalo do health check do target group (segundos)"
  type        = number
  default     = 30
}

variable "target_health_check_timeout" {
  description = "Timeout do health check do target group (segundos)"
  type        = number
  default     = 5
}

variable "target_health_check_healthy_threshold" {
  description = "Número de checks sucessivos para considerar healthy"
  type        = number
  default     = 2
}

variable "target_health_check_unhealthy_threshold" {
  description = "Número de checks falhados para considerar unhealthy"
  type        = number
  default     = 3
}

variable "target_deregistration_delay" {
  description = "Tempo de espera antes de desregistrar target (segundos)"
  type        = number
  default     = 30
}

################################################################################
# Security Groups
################################################################################

variable "ecs_tasks_ingress_rules" {
  description = "Regras de ingress adicionais para tasks ECS"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

################################################################################
# Auto Scaling
################################################################################

variable "enable_autoscaling" {
  description = "Habilitar auto scaling das tasks"
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "Número mínimo de tasks (auto scaling)"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Número máximo de tasks (auto scaling)"
  type        = number
  default     = 4
}

variable "autoscaling_cpu_target" {
  description = "Target de utilização de CPU para auto scaling (%)"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target de utilização de memória para auto scaling (%)"
  type        = number
  default     = 80
}

################################################################################
# Deployment
################################################################################

variable "deployment_maximum_percent" {
  description = "Percentual máximo de tasks durante deployment"
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "Percentual mínimo de tasks saudáveis durante deployment"
  type        = number
  default     = 100
}

variable "force_new_deployment" {
  description = "Forçar novo deployment ao aplicar"
  type        = bool
  default     = false
}

################################################################################
# Cluster
################################################################################

variable "enable_container_insights" {
  description = "Habilitar CloudWatch Container Insights"
  type        = bool
  default     = true
}

################################################################################
# Logs
################################################################################

variable "log_retention_days" {
  description = "Dias de retenção dos logs no CloudWatch"
  type        = number
  default     = 7
}

################################################################################
# ECS Exec
################################################################################

variable "enable_ecs_exec" {
  description = "Habilitar ECS Exec para debug"
  type        = bool
  default     = false
}
