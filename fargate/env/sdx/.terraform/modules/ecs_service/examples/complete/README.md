# Exemplo Completo - ECS Fargate com ALB

Este exemplo demonstra um deploy completo de uma aplicação no ECS Fargate com Application Load Balancer e Auto Scaling.

## 📋 Pré-requisitos

- Conta AWS configurada
- VPC com subnets públicas e privadas
- Imagem Docker da aplicação disponível (ECR ou Docker Hub)
- Terraform >= 1.0

## 🚀 Como usar

### 1. Configure as variáveis

Crie um arquivo `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
environment = "dev"
app_name = "minha-api"

# Sua infraestrutura de rede
vpc_id             = "vpc-0123456789abcdef0"
private_subnet_ids = ["subnet-private1", "subnet-private2"]
public_subnet_ids  = ["subnet-public1", "subnet-public2"]

# Sua imagem Docker
container_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/minha-api:latest"
# ou imagem pública: "nginx:latest"

container_port = 3000
```

### 2. Inicialize e aplique

```bash
# Inicializar Terraform
terraform init

# Ver o plano de execução
terraform plan

# Aplicar as mudanças
terraform apply
```

### 3. Acesse sua aplicação

Após o apply, o Terraform mostrará o DNS do ALB:

```
Outputs:

alb_url = "http://minha-api-dev-alb-123456789.us-east-1.elb.amazonaws.com"
```

Acesse a URL para ver sua aplicação rodando!

## 📦 O que este exemplo cria

### Recursos AWS:

1. **ECS Cluster** - Cluster para executar as tasks
2. **ECS Task Definition** - Definição da task com container
3. **ECS Service** - Serviço com 2 tasks (desired count)
4. **Application Load Balancer** - ALB para distribuir tráfego
5. **Target Group** - Target group do ALB
6. **Security Groups** - SG para ALB e tasks
7. **CloudWatch Log Group** - Para logs da aplicação
8. **IAM Roles** - Roles de execução e task
9. **Auto Scaling** - Configuração de auto scaling por CPU/Memória

### Configurações:

- ✅ 2 tasks iniciais (pode escalar de 2 a 10)
- ✅ CPU: 256 (0.25 vCPU por task)
- ✅ Memória: 512 MB por task
- ✅ Health check no endpoint `/health`
- ✅ Logs retidos por 7 dias
- ✅ Auto scaling habilitado (70% CPU, 80% memória)
- ✅ ECS Exec habilitado para debug

## 🔧 Customizações

### Aumentar recursos da task

```hcl
# No módulo ecs_service
task_cpu    = 512   # 0.5 vCPU
task_memory = 1024  # 1 GB
```

### Adicionar variáveis de ambiente

```hcl
# No módulo app_container
environment = [
  {
    name  = "DATABASE_URL"
    value = "postgres://..."
  },
  {
    name  = "REDIS_URL"
    value = "redis://..."
  }
]
```

### Usar secrets

```hcl
# No módulo app_container
secrets = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:us-east-1:123:secret:db-pass-xyz"
  },
  {
    name      = "API_KEY"
    valueFrom = "arn:aws:ssm:us-east-1:123:parameter/api-key"
  }
]
```

### Adicionar HTTPS

```hcl
# Adicione um listener HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:123:certificate/xxx"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# Redirecionar HTTP para HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

## 🐛 Debug com ECS Exec

Para conectar em uma task rodando:

```bash
# Listar tasks
aws ecs list-tasks --cluster minha-api-dev-cluster --service-name minha-api-dev-service

# Conectar na task
aws ecs execute-command \
  --cluster minha-api-dev-cluster \
  --task <task-id> \
  --container minha-api \
  --interactive \
  --command "/bin/sh"
```

## 📊 Visualizar Logs

```bash
# Ver logs no CloudWatch
aws logs tail /ecs/minha-api --follow
```

Ou acesse o console: CloudWatch → Log Groups → `/ecs/minha-api`

## 🧹 Limpeza

Para destruir todos os recursos:

```bash
terraform destroy
```

## 💰 Custos Estimados

Considerando região us-east-1:

- **ECS Fargate**: ~$14/mês por task (0.25 vCPU, 0.5GB)
- **ALB**: ~$16/mês + ~$0.008 por GB processado
- **NAT Gateway**: ~$32/mês (se usar)
- **CloudWatch Logs**: ~$0.50/GB armazenado

**Total estimado**: ~$60-100/mês (com 2 tasks rodando 24/7)

> 💡 Dica: Para reduzir custos em dev, use apenas 1 task e desligue à noite:
> ```hcl
> desired_count = 1
> enable_autoscaling = false
> ```

## 🔐 Melhores Práticas Aplicadas

- ✅ Tasks em subnets privadas (sem IP público)
- ✅ ALB em subnets públicas
- ✅ Security groups com least privilege
- ✅ Logs centralizados no CloudWatch
- ✅ Health checks configurados
- ✅ Auto scaling baseado em métricas
- ✅ IAM roles com permissões mínimas
- ✅ Secrets não hardcoded

## 🆘 Troubleshooting

### Tasks não iniciam

1. Verifique os logs do CloudWatch
2. Verifique se a imagem está acessível
3. Confirme que as tasks têm acesso à internet (NAT Gateway)

### Health check falhando

1. Verifique se o endpoint `/health` existe
2. Confirme a porta correta
3. Ajuste `health_check_grace_period_seconds`

### Auto scaling não funciona

1. Verifique as métricas no CloudWatch
2. Ajuste os targets de CPU/memória
3. Verifique os limites de min/max capacity
