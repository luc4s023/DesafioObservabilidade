################################################################################
# Container Definition - Versão Simplificada para Fargate
################################################################################

variable "name" {
  description = "Nome do container"
  type        = string
}

variable "image" {
  description = "Imagem Docker a ser utilizada (ex: nginx:latest, 123456789.dkr.ecr.us-east-1.amazonaws.com/app:v1)"
  type        = string
}

variable "cpu" {
  description = "CPU do container em unidades (1024 = 1 vCPU). Opcional se especificado na task"
  type        = number
  default     = null
}

variable "memory" {
  description = "Memória do container em MB. Opcional se especificado na task"
  type        = number
  default     = null
}

variable "essential" {
  description = "Se true, a task para se este container falhar"
  type        = bool
  default     = true
}

variable "port_mappings" {
  description = "Lista de portas expostas pelo container"
  type = list(object({
    container_port = number
    protocol       = optional(string, "tcp")
  }))
  default = []
}

variable "environment" {
  description = "Variáveis de ambiente para o container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Secrets do AWS Secrets Manager para injetar como variáveis de ambiente"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "command" {
  description = "Comando para sobrescrever o CMD da imagem Docker"
  type        = list(string)
  default     = null
}

variable "entrypoint" {
  description = "Entrypoint para sobrescrever o ENTRYPOINT da imagem Docker"
  type        = list(string)
  default     = null
}

variable "working_directory" {
  description = "Diretório de trabalho do container"
  type        = string
  default     = null
}

variable "readonly_root_filesystem" {
  description = "Se true, o filesystem root do container será read-only"
  type        = bool
  default     = false
}

variable "health_check" {
  description = "Health check do container"
  type = object({
    command     = list(string)
    interval    = optional(number, 30)
    timeout     = optional(number, 5)
    retries     = optional(number, 3)
    startPeriod = optional(number, 0)
  })
  default = null
}

variable "create_cloudwatch_log_group" {
  description = "Se true, cria um CloudWatch Log Group para o container"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Dias de retenção dos logs no CloudWatch"
  type        = number
  default     = 7
}

variable "cloudwatch_log_group_name" {
  description = "Nome customizado para o log group. Se null, usa /ecs/{var.name}"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags para aplicar aos recursos"
  type        = map(string)
  default     = {}
}
