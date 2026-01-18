################################################################################
# Service - Versão Simplificada
################################################################################

variable "name" {
  description = "Nome do serviço ECS"
  type        = string
}

variable "cluster_arn" {
  description = "ARN do cluster ECS"
  type        = string
}

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
  description = "JSON com as definições dos containers"
  type        = any
}

variable "desired_count" {
  description = "Número desejado de tasks"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "IDs das subnets para o serviço"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs adicionais de security groups"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "assign_public_ip" {
  description = "Atribuir IP público às tasks"
  type        = bool
  default     = false
}

variable "enable_load_balancer" {
  description = "Habilitar integração com load balancer"
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ARN do target group do load balancer"
  type        = string
  default     = null
}

variable "container_name" {
  description = "Nome do container para o load balancer"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Porta do container para o load balancer"
  type        = number
  default     = null
}

variable "health_check_grace_period_seconds" {
  description = "Período de graça do health check em segundos"
  type        = number
  default     = 60
}

variable "deployment_maximum_percent" {
  description = "Percentual máximo de tasks durante deploy"
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "Percentual mínimo de tasks saudáveis durante deploy"
  type        = number
  default     = 100
}

variable "enable_autoscaling" {
  description = "Habilitar auto scaling"
  type        = bool
  default     = false
}

variable "autoscaling_min_capacity" {
  description = "Capacidade mínima de auto scaling"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Capacidade máxima de auto scaling"
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

variable "autoscaling_scale_in_cooldown" {
  description = "Cooldown de scale in em segundos"
  type        = number
  default     = 300
}

variable "autoscaling_scale_out_cooldown" {
  description = "Cooldown de scale out em segundos"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags para aplicar aos recursos"
  type        = map(string)
  default     = {}
}
