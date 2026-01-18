################################################################################
# Service - Versão Simplificada para Fargate
################################################################################

variable "name" {
  description = "Nome do serviço ECS"
  type        = string
}

variable "cluster_arn" {
  description = "ARN do cluster ECS"
  type        = string
}

variable "desired_count" {
  description = "Número desejado de tasks"
  type        = number
  default     = 1
}

################################################################################
# Task Definition
################################################################################

variable "task_cpu" {
  description = "CPU da task (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memória da task em MB (512, 1024, 2048, etc)"
  type        = number
  default     = 512
}

variable "container_definitions" {
  description = "Definições dos containers (JSON ou lista de objetos)"
  type        = any
}

variable "task_execution_role_arn" {
  description = "ARN da role de execução da task (para pull de imagens e logs). Se null, cria uma role padrão"
  type        = string
  default     = null
}

variable "task_role_arn" {
  description = "ARN da role da task (permissões da aplicação). Opcional"
  type        = string
  default     = null
}

################################################################################
# Network Configuration
################################################################################

variable "subnet_ids" {
  description = "IDs das subnets onde as tasks serão executadas"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs dos security groups. Se vazio, cria um security group padrão"
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Atribuir IP público às tasks (necessário se usar subnets públicas sem NAT)"
  type        = bool
  default     = false
}

################################################################################
# Load Balancer (Opcional)
################################################################################

variable "enable_load_balancer" {
  description = "Habilitar integração com Load Balancer"
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ARN do target group do ALB/NLB"
  type        = string
  default     = null
}

variable "container_name" {
  description = "Nome do container que receberá tráfego do LB"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Porta do container que receberá tráfego do LB"
  type        = number
  default     = null
}

variable "health_check_grace_period_seconds" {
  description = "Período de graça para health check após iniciar task"
  type        = number
  default     = 60
}

################################################################################
# Deployment Configuration
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

variable "enable_execute_command" {
  description = "Habilitar ECS Exec (para debug com AWS CLI)"
  type        = bool
  default     = false
}

variable "force_new_deployment" {
  description = "Forçar novo deployment ao aplicar"
  type        = bool
  default     = false
}

################################################################################
# Auto Scaling (Opcional)
################################################################################

variable "enable_autoscaling" {
  description = "Habilitar auto scaling"
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "Capacidade mínima de tasks"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Capacidade máxima de tasks"
  type        = number
  default     = 4
}

variable "autoscaling_cpu_target" {
  description = "Target de CPU para auto scaling (%)"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target de memória para auto scaling (%)"
  type        = number
  default     = 80
}

################################################################################
# Security Group (se não fornecido)
################################################################################

variable "vpc_id" {
  description = "ID da VPC (necessário se security_group_ids não for fornecido)"
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "CIDRs permitidos no security group (se criado automaticamente)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Tags para aplicar aos recursos"
  type        = map(string)
  default     = {}
}
