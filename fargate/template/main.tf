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
# Locals
################################################################################

locals {
  name_prefix = "${var.app_name}-${var.environment}"
  
  common_tags = {
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

################################################################################
# ECS Cluster
################################################################################

module "ecs_cluster" {
  source = var.ecs_modules_path != null ? "${var.ecs_modules_path}/cluster" : "../../../modulo_ecs_luc4s/modules/cluster"

  name                      = "${local.name_prefix}-cluster"
  enable_container_insights = var.enable_container_insights

  tags = local.common_tags
}

################################################################################
# Container Definition
################################################################################

module "app_container" {
  source = var.ecs_modules_path != null ? "${var.ecs_modules_path}/container-definition" : "../../../modulo_ecs_luc4s/modules/container-definition"

  name   = var.app_name
  image  = var.container_image
  cpu    = var.container_cpu
  memory = var.container_memory

  port_mappings = [
    {
      container_port = var.container_port
      protocol       = "tcp"
    }
  ]

  # Merge variáveis de ambiente com connection string do RDS (se criado)
  environment = concat(
    var.container_environment,
    var.create_rds && var.db_use_environment_variable ? [
      {
        name  = "DB_HOST"
        value = aws_db_instance.this[0].address
      },
      {
        name  = "DB_PORT"
        value = tostring(var.db_port)
      },
      {
        name  = "DB_NAME"
        value = var.db_name
      },
      {
        name  = "DB_USER"
        value = var.db_username
      }
    ] : []
  )

  # Secrets incluindo senha e connection string do RDS (se criado)
  secrets = concat(
    var.container_secrets,
    var.create_rds ? [
      {
        name      = var.db_connection_string_env_var_name
        valueFrom = aws_secretsmanager_secret.db_connection_string[0].arn
      },
      {
        name      = var.db_password_env_var_name
        valueFrom = aws_secretsmanager_secret.db_password[0].arn
      }
    ] : []
  )

  health_check = var.enable_health_check ? {
    command     = var.health_check_command
    interval    = var.health_check_interval
    timeout     = var.health_check_timeout
    retries     = var.health_check_retries
    startPeriod = var.health_check_start_period
  } : null

  cloudwatch_log_group_retention_in_days = var.log_retention_days

  tags = local.common_tags
}

################################################################################
# Application Load Balancer (Condicional)
################################################################################

resource "aws_lb" "this" {
  count = var.enable_load_balancer ? 1 : 0

  name               = "${local.name_prefix}-alb"
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

resource "aws_lb_target_group" "this" {
  count = var.enable_load_balancer ? 1 : 0

  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.target_health_check_healthy_threshold
    interval            = var.target_health_check_interval
    matcher             = var.target_health_check_matcher
    path                = var.target_health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = var.target_health_check_timeout
    unhealthy_threshold = var.target_health_check_unhealthy_threshold
  }

  deregistration_delay = var.target_deregistration_delay

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  count = var.enable_load_balancer ? 1 : 0

  load_balancer_arn = aws_lb.this[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }
}

################################################################################
# Security Groups
################################################################################

resource "aws_security_group" "alb" {
  count = var.enable_load_balancer ? 1 : 0

  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for ${var.app_name} ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
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
  description = "Security group for ${var.app_name} ECS tasks"
  vpc_id      = var.vpc_id

  # Ingress do ALB (se habilitado)
  dynamic "ingress" {
    for_each = var.enable_load_balancer ? [1] : []
    content {
      from_port       = var.container_port
      to_port         = var.container_port
      protocol        = "tcp"
      security_groups = [aws_security_group.alb[0].id]
      description     = "Allow traffic from ALB"
    }
  }

  # Ingress adicional (ex: para tasks sem ALB)
  dynamic "ingress" {
    for_each = var.ecs_tasks_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
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
  source = var.ecs_modules_path != null ? "${var.ecs_modules_path}/service" : "../../../modulo_ecs_luc4s/modules/service"

  name        = "${local.name_prefix}-service"
  cluster_arn = module.ecs_cluster.cluster_arn

  # Task configuration
  task_cpu    = var.task_cpu
  task_memory = var.task_memory
  container_definitions = jsonencode([
    module.app_container.container_definition
  ])

  desired_count = var.desired_count

  # Network
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.ecs_tasks.id]
  vpc_id             = var.vpc_id
  assign_public_ip   = var.assign_public_ip

  # Load Balancer
  enable_load_balancer              = var.enable_load_balancer
  target_group_arn                  = var.enable_load_balancer ? aws_lb_target_group.this[0].arn : null
  container_name                    = var.app_name
  container_port                    = var.container_port
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # Auto Scaling
  enable_autoscaling        = var.enable_autoscaling
  autoscaling_min_capacity  = var.autoscaling_min_capacity
  autoscaling_max_capacity  = var.autoscaling_max_capacity
  autoscaling_cpu_target    = var.autoscaling_cpu_target
  autoscaling_memory_target = var.autoscaling_memory_target

  # Deployment
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  force_new_deployment               = var.force_new_deployment

  # ECS Exec
  enable_execute_command = var.enable_ecs_exec

  tags = local.common_tags
}
