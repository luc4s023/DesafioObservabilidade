################################################################################
# Service - Outputs Simplificados
################################################################################

output "service_id" {
  description = "ID do serviço ECS"
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "Nome do serviço ECS"
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "ARN do serviço ECS"
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "ARN da task definition (incluindo revisão)"
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Family da task definition"
  value       = aws_ecs_task_definition.this.family
}

output "task_definition_revision" {
  description = "Revisão da task definition"
  value       = aws_ecs_task_definition.this.revision
}

output "security_group_id" {
  description = "ID do security group criado (se aplicável)"
  value       = try(aws_security_group.this[0].id, null)
}

output "execution_role_arn" {
  description = "ARN da IAM role de execução criada (se aplicável)"
  value       = try(aws_iam_role.execution[0].arn, null)
}

output "autoscaling_target_id" {
  description = "ID do target de auto scaling (se habilitado)"
  value       = try(aws_appautoscaling_target.this[0].id, null)
}
