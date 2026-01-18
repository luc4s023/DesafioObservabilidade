# Módulos ECS Fargate Simplificados

Este repositório contém módulos Terraform simplificados para deploy de aplicações no ECS Fargate.

## 📁 Estrutura

```
modules/
├── cluster/              # Módulo do cluster ECS
├── container-definition/ # Módulo de definição de container
└── service/             # Módulo de serviço ECS + Task Definition
```

## 🚀 Exemplo de Uso Básico

### Exemplo Completo - Aplicação Web com ALB

```hcl
# main.tf

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
  region = "us-east-1"
}

# 1. Criar o Cluster ECS
module "ecs_cluster" {
  source = "./modules/cluster"

  name                      = "meu-cluster-producao"
  enable_container_insights = true

  tags = {
    Environment = "production"
    Project     = "minha-api"
  }
}

# 2. Criar a definição do container
module "container_definition" {
  source = "./modules/container-definition"

  name   = "api-backend"
  image  = "123456789.dkr.ecr.us-east-1.amazonaws.com/minha-api:latest"
  cpu    = 256
  memory = 512

  port_mappings = [
    {
      container_port = 8080
      protocol       = "tcp"
    }
  ]

  environment = [
    {
      name  = "APP_ENV"
      value = "production"
    },
    {
      name  = "PORT"
      value = "8080"
    }
  ]

  # Secrets do AWS Secrets Manager ou Parameter Store
  secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = "arn:aws:secretsmanager:us-east-1:123456789:secret:db-password-xyz"
    }
  ]

  health_check = {
    command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
    interval    = 30
    timeout     = 5
    retries     = 3
    startPeriod = 60
  }

  cloudwatch_log_group_retention_in_days = 7

  tags = {
    Environment = "production"
  }
}

# 3. Criar o serviço ECS com integração ALB
module "ecs_service" {
  source = "./modules/service"

  name        = "minha-api-service"
  cluster_arn = module.ecs_cluster.cluster_arn

  # Task configuration
  task_cpu    = 256
  task_memory = 512
  container_definitions = jsonencode([
    module.container_definition.container_definition
  ])

  desired_count = 2

  # Network
  subnet_ids         = ["subnet-xxx", "subnet-yyy"] # Suas subnets privadas
  vpc_id             = "vpc-xxxxx"                   # Sua VPC
  assign_public_ip   = false

  # Load Balancer
  enable_load_balancer              = true
  target_group_arn                  = aws_lb_target_group.api.arn
  container_name                    = "api-backend"
  container_port                    = 8080
  health_check_grace_period_seconds = 60

  # Auto Scaling
  enable_autoscaling       = true
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 10
  autoscaling_cpu_target   = 70
  autoscaling_memory_target = 80

  # Deployment
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  tags = {
    Environment = "production"
    Project     = "minha-api"
  }
}

# Target Group do ALB (você precisa criar o ALB também)
resource "aws_lb_target_group" "api" {
  name        = "minha-api-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = "vpc-xxxxx"
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
}
```

## 📝 Exemplo Simples - Sem Load Balancer

```hcl
# Para aplicações que não precisam de ALB (ex: workers, cron jobs)

module "ecs_cluster" {
  source = "./modules/cluster"
  name   = "cluster-workers"
}

module "container_worker" {
  source = "./modules/container-definition"

  name   = "worker-processamento"
  image  = "meu-worker:latest"
  cpu    = 512
  memory = 1024

  environment = [
    {
      name  = "QUEUE_URL"
      value = "https://sqs.us-east-1.amazonaws.com/123/minha-fila"
    }
  ]
}

module "worker_service" {
  source = "./modules/service"

  name        = "worker-service"
  cluster_arn = module.ecs_cluster.cluster_arn

  task_cpu    = 512
  task_memory = 1024
  container_definitions = jsonencode([
    module.container_worker.container_definition
  ])

  desired_count = 1

  subnet_ids       = ["subnet-xxx"]
  vpc_id           = "vpc-xxxxx"
  assign_public_ip = false

  enable_load_balancer = false  # Sem ALB
}
```

## 🔧 Variáveis Principais

### Módulo Cluster

| Variável | Tipo | Padrão | Descrição |
|----------|------|--------|-----------|
| `name` | string | - | Nome do cluster (obrigatório) |
| `enable_container_insights` | bool | `true` | Habilitar CloudWatch Container Insights |
| `tags` | map | `{}` | Tags para o cluster |

### Módulo Container Definition

| Variável | Tipo | Padrão | Descrição |
|----------|------|--------|-----------|
| `name` | string | - | Nome do container (obrigatório) |
| `image` | string | - | Imagem Docker (obrigatório) |
| `cpu` | number | `null` | CPU do container |
| `memory` | number | `null` | Memória em MB |
| `port_mappings` | list | `[]` | Portas expostas |
| `environment` | list | `[]` | Variáveis de ambiente |
| `secrets` | list | `[]` | Secrets do Secrets Manager |
| `health_check` | object | `null` | Configuração de health check |

### Módulo Service

| Variável | Tipo | Padrão | Descrição |
|----------|------|--------|-----------|
| `name` | string | - | Nome do serviço (obrigatório) |
| `cluster_arn` | string | - | ARN do cluster (obrigatório) |
| `task_cpu` | number | `256` | CPU da task |
| `task_memory` | number | `512` | Memória da task |
| `container_definitions` | any | - | JSON com definições (obrigatório) |
| `desired_count` | number | `1` | Número de tasks |
| `subnet_ids` | list | - | Subnets (obrigatório) |
| `vpc_id` | string | `null` | VPC ID |
| `enable_load_balancer` | bool | `false` | Habilitar ALB/NLB |
| `target_group_arn` | string | `null` | ARN do target group |
| `enable_autoscaling` | bool | `false` | Habilitar auto scaling |

## 🎯 Combinações de CPU/Memória Suportadas (Fargate)

| CPU (vCPU) | Memória (GB) |
|------------|--------------|
| 0.25 (.25 vCPU) | 0.5, 1, 2 |
| 0.5 (.5 vCPU) | 1, 2, 3, 4 |
| 1 | 2, 3, 4, 5, 6, 7, 8 |
| 2 | 4-16 (incrementos de 1) |
| 4 | 8-30 (incrementos de 1) |

## 🔐 Permissões Necessárias

A role de execução criada automaticamente inclui:
- ✅ Pull de imagens do ECR
- ✅ Envio de logs para CloudWatch
- ✅ Leitura de secrets do Secrets Manager
- ✅ Leitura de parâmetros do SSM Parameter Store

## 📊 Monitoramento

Com `enable_container_insights = true`, você terá métricas automáticas no CloudWatch:
- CPU e memória por task
- Utilização de rede
- Métricas de performance

## 🆚 Diferenças da Versão Original

### Simplificações:
- ❌ Removido suporte a EC2 launch type
- ❌ Removido capacity providers complexos
- ❌ Removido service discovery avançado
- ❌ Removido deployment controllers externos
- ✅ Foco 100% em Fargate
- ✅ Valores padrão inteligentes
- ✅ Security group e IAM roles criados automaticamente
- ✅ Auto scaling simplificado

## 📚 Próximos Passos

1. Ajuste as variáveis de acordo com sua necessidade
2. Configure seu backend do Terraform (S3 + DynamoDB)
3. Execute `terraform init`
4. Execute `terraform plan`
5. Execute `terraform apply`

## ⚠️ Notas Importantes

- As tasks rodam em modo `awsvpc` (cada task tem seu próprio ENI)
- Para ambientes de produção, use subnets privadas com NAT Gateway
- Configure corretamente os security groups para comunicação com RDS, Redis, etc.
- Use Secrets Manager para credenciais sensíveis
