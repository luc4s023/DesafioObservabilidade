################################################################################
# Container Definition - Outputs Simplificados
################################################################################

output "container_definition" {
  description = "Definição do container em formato de objeto"
  value       = local.container_definition
}

output "container_definition_json" {
  description = "Definição do container em JSON (use para task definition)"
  value       = jsonencode(local.container_definition)
}

output "log_group_name" {
  description = "Nome do CloudWatch Log Group criado"
  value       = try(aws_cloudwatch_log_group.this[0].name, null)
}

output "log_group_arn" {
  description = "ARN do CloudWatch Log Group criado"
  value       = try(aws_cloudwatch_log_group.this[0].arn, null)
}
