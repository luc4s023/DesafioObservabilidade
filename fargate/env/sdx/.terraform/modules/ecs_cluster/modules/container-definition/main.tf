################################################################################
# Container Definition - Versão Simplificada para Fargate
################################################################################

locals {
  log_group_name = coalesce(var.log_group_name, "/ecs/${var.name}")

  # Monta a definição do container
  container_definition = {
    name      = var.name
    image     = var.image
    cpu       = var.cpu
    memory    = var.memory
    essential = var.essential

    portMappings = [
      for port in var.port_mappings : {
        containerPort = port.container_port
        protocol      = port.protocol
      }
    ]

    environment = var.environment
    secrets     = var.secrets

    command          = var.command
    entryPoint       = var.entrypoint
    workingDirectory = var.working_directory

    healthCheck = var.health_check != null ? {
      command     = var.health_check.command
      interval    = var.health_check.interval
      timeout     = var.health_check.timeout
      retries     = var.health_check.retries
      startPeriod = var.health_check.startPeriod
    } : null

    logConfiguration = var.create_cloudwatch_log_group ? {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this[0].name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    } : null
  }
}

# Data source para região atual
data "aws_region" "current" {}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "this" {
  count = var.create_cloudwatch_log_group ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.cloudwatch_log_group_retention_in_days

  tags = var.tags
}
