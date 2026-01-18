output "service_id" {
  description = "ID do serviço ECS"
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "Nome do serviço ECS"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN da task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "security_group_id" {
  description = "ID do security group do serviço"
  value       = aws_security_group.this.id
}

output "execution_role_arn" {
  description = "ARN da execution role"
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN da task role"
  value       = aws_iam_role.task.arn
}
