################################################################################
# Outputs
################################################################################

# Cluster
output "cluster_name" {
  description = "Nome do cluster ECS"
  value       = module.ecs_cluster.cluster_name
}

output "cluster_arn" {
  description = "ARN do cluster ECS"
  value       = module.ecs_cluster.cluster_arn
}

# Service
output "service_name" {
  description = "Nome do serviço ECS"
  value       = module.ecs_service.service_name
}

output "service_id" {
  description = "ID do serviço ECS"
  value       = module.ecs_service.service_id
}

output "task_definition_arn" {
  description = "ARN da task definition (com revisão)"
  value       = module.ecs_service.task_definition_arn
}

output "task_definition_family" {
  description = "Family da task definition"
  value       = module.ecs_service.task_definition_family
}

# Load Balancer (se habilitado)
output "alb_dns_name" {
  description = "DNS name do Application Load Balancer"
  value       = var.enable_load_balancer ? aws_lb.this[0].dns_name : null
}

output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = var.enable_load_balancer ? aws_lb.this[0].arn : null
}

output "alb_url" {
  description = "URL completa da aplicação"
  value       = var.enable_load_balancer ? "http://${aws_lb.this[0].dns_name}" : null
}

output "target_group_arn" {
  description = "ARN do target group"
  value       = var.enable_load_balancer ? aws_lb_target_group.this[0].arn : null
}

# Security Groups
output "alb_security_group_id" {
  description = "ID do security group do ALB"
  value       = var.enable_load_balancer ? aws_security_group.alb[0].id : null
}

output "ecs_tasks_security_group_id" {
  description = "ID do security group das tasks ECS"
  value       = aws_security_group.ecs_tasks.id
}

# Logs
output "cloudwatch_log_group_name" {
  description = "Nome do CloudWatch Log Group"
  value       = module.app_container.log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "ARN do CloudWatch Log Group"
  value       = module.app_container.log_group_arn
}

# Auto Scaling
output "autoscaling_target_id" {
  description = "ID do target de auto scaling (se habilitado)"
  value       = module.ecs_service.autoscaling_target_id
}

# Informações úteis para comandos AWS CLI
output "ecs_exec_command" {
  description = "Comando para conectar via ECS Exec (substitua <task-id>)"
  value = var.enable_ecs_exec ? "aws ecs execute-command --cluster ${module.ecs_cluster.cluster_name} --task <task-id> --container ${var.app_name} --interactive --command '/bin/sh'" : null
}

output "view_logs_command" {
  description = "Comando para visualizar logs no CloudWatch"
  value       = "aws logs tail ${module.app_container.log_group_name} --follow"
}

output "list_tasks_command" {
  description = "Comando para listar tasks do serviço"
  value       = "aws ecs list-tasks --cluster ${module.ecs_cluster.cluster_name} --service-name ${module.ecs_service.service_name}"
}
