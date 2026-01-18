terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

################################################################################
# Variables
################################################################################

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nome do ambiente"
  type        = string
  default     = "dev"
}

variable "app_name" {
  description = "Nome da aplicação"
  type        = string
  default     = "demo-app"
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "IDs das subnets públicas (para ALB)"
  type        = list(string)
}

variable "container_image" {
  description = "Imagem Docker da aplicação"
  type        = string
}

variable "container_port" {
  description = "Porta do container"
  type        = number
  default     = 3000
}

################################################################################
# Locals
################################################################################

locals {
  name_prefix = "${var.app_name}-${var.environment}"
  
  common_tags = {
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "Terraform"
  }
}

################################################################################
# ECS Cluster
################################################################################

module "ecs_cluster" {
  source = "../../modules/cluster"

  name                      = "${local.name_prefix}-cluster"
  enable_container_insights = true

  tags = local.common_tags
}

################################################################################
# Container Definition
################################################################################

module "app_container" {
  source = "../../modules/container-definition"

  name   = var.app_name
  image  = var.container_image
  cpu    = 256
  memory = 512

  port_mappings = [
    {
      container_port = var.container_port
      protocol       = "tcp"
    }
  ]

  environment = [
    {
      name  = "NODE_ENV"
      value = var.environment
    },
    {
      name  = "PORT"
      value = tostring(var.container_port)
    },
    {
      name  = "APP_NAME"
      value = var.app_name
    }
  ]

  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
    interval    = 30
    timeout     = 5
    retries     = 3
    startPeriod = 60
  }

  cloudwatch_log_group_retention_in_days = 7

  tags = local.common_tags
}

################################################################################
# Application Load Balancer
################################################################################

resource "aws_lb" "this" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

resource "aws_lb_target_group" "this" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

################################################################################
# Security Groups
################################################################################

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${local.name_prefix}-ecs-tasks-"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ecs-tasks-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# ECS Service
################################################################################

module "ecs_service" {
  source = "../../modules/service"

  name        = "${local.name_prefix}-service"
  cluster_arn = module.ecs_cluster.cluster_arn

  # Task configuration
  task_cpu    = 256
  task_memory = 512
  container_definitions = jsonencode([
    module.app_container.container_definition
  ])

  desired_count = 2

  # Network
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.ecs_tasks.id]
  vpc_id             = var.vpc_id
  assign_public_ip   = false

  # Load Balancer
  enable_load_balancer              = true
  target_group_arn                  = aws_lb_target_group.this.arn
  container_name                    = var.app_name
  container_port                    = var.container_port
  health_check_grace_period_seconds = 60

  # Auto Scaling
  enable_autoscaling        = true
  autoscaling_min_capacity  = 2
  autoscaling_max_capacity  = 10
  autoscaling_cpu_target    = 70
  autoscaling_memory_target = 80

  # Deployment
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  force_new_deployment               = false

  # Enable ECS Exec for debugging
  enable_execute_command = true

  tags = local.common_tags
}

################################################################################
# Outputs
################################################################################

output "cluster_name" {
  description = "Nome do cluster ECS"
  value       = module.ecs_cluster.cluster_name
}

output "cluster_arn" {
  description = "ARN do cluster ECS"
  value       = module.ecs_cluster.cluster_arn
}

output "service_name" {
  description = "Nome do serviço ECS"
  value       = module.ecs_service.service_name
}

output "alb_dns_name" {
  description = "DNS name do ALB"
  value       = aws_lb.this.dns_name
}

output "alb_url" {
  description = "URL completa da aplicação"
  value       = "http://${aws_lb.this.dns_name}"
}

output "task_definition_arn" {
  description = "ARN da task definition"
  value       = module.ecs_service.task_definition_arn
}

output "log_group_name" {
  description = "Nome do CloudWatch Log Group"
  value       = module.app_container.log_group_name
}
