# Template ECS Fargate - Deploy de Aplicações

Template Terraform para deploy de aplicações no AWS ECS Fargate com ALB, Auto Scaling e monitoramento.

## 📋 Pré-requisitos

- [x] Terraform >= 1.0
- [x] AWS CLI configurado
- [x] VPC com subnets públicas e privadas
- [x] Imagem Docker da aplicação (ECR ou Docker Hub)
- [x] Credenciais AWS configuradas

## 🚀 Quick Start

### 1. Configure as variáveis

```bash
# Copie o arquivo de exemplo
cp terraform.tfvars.example terraform.tfvars

# Edite com suas configurações
vim terraform.tfvars
```

**Variáveis obrigatórias:**
- `vpc_id`: ID da sua VPC
- `private_subnet_ids`: IDs das subnets privadas
- `public_subnet_ids`: IDs das subnets públicas (se usar ALB)
- `container_image`: Imagem Docker da aplicação

### 2. Configure o backend (opcional mas recomendado)

```bash
# Edite backend.tf e descomente a configuração do S3
vim backend.tf
```

### 3. Inicialize e aplique

```bash
# Inicializar Terraform
terraform init

# Validar configuração
terraform validate

# Ver plano de execução
terraform plan

# Aplicar mudanças
terraform apply
```

### 4. Acesse sua aplicação

```bash
# O Terraform mostrará a URL após o apply
# Outputs:
# alb_url = "http://usuarios-api-dev-alb-123456.us-east-1.elb.amazonaws.com"
```

## 📁 Estrutura de Arquivos

```
template/
├── main.tf              # Recursos principais e chamadas aos módulos
├── variables.tf         # Definição de todas as variáveis
├── terraform.tfvars     # Valores das variáveis (criar a partir do .example)
├── backend.tf           # Configuração do backend (state)
├── outputs.tf           # Outputs úteis
└── README.md           # Esta documentação
```

## ⚙️ Configurações Principais

### Tamanhos de Task (CPU/Memória)

Combinações válidas para Fargate:

| CPU | Memória (MB) |
|-----|--------------|
| 256 | 512, 1024, 2048 |
| 512 | 1024, 2048, 3072, 4096 |
| 1024 | 2048-8192 (incrementos de 1024) |
| 2048 | 4096-16384 (incrementos de 1024) |
| 4096 | 8192-30720 (incrementos de 1024) |

### Ambientes

Suportado via variável `environment`:
- `dev` - Desenvolvimento
- `stg` - Staging
- `prd` - Produção

### Com Load Balancer

```hcl
enable_load_balancer = true
public_subnet_ids    = ["subnet-pub1", "subnet-pub2"]
```

### Sem Load Balancer (Worker/Cron)

```hcl
enable_load_balancer = false
# public_subnet_ids não é necessário
```

### Com Auto Scaling

```hcl
enable_autoscaling        = true
autoscaling_min_capacity  = 2
autoscaling_max_capacity  = 10
autoscaling_cpu_target    = 70
autoscaling_memory_target = 80
```

## 🔐 Secrets e Variáveis de Ambiente

### Variáveis de Ambiente

```hcl
container_environment = [
  {
    name  = "NODE_ENV"
    value = "production"
  },
  {
    name  = "LOG_LEVEL"
    value = "info"
  }
]
```

### Secrets (AWS Secrets Manager ou Parameter Store)

```hcl
container_secrets = [
  {
    name      = "DATABASE_URL"
    valueFrom = "arn:aws:secretsmanager:us-east-1:123:secret:db-url-xyz"
  },
  {
    name      = "API_KEY"
    valueFrom = "arn:aws:ssm:us-east-1:123:parameter/api-key"
  }
]
```

## 📊 Monitoramento e Logs

### CloudWatch Logs

```bash
# Ver logs em tempo real
aws logs tail /ecs/usuarios-api --follow

# Ou use o output do Terraform
terraform output view_logs_command
```

### Container Insights

Habilitado por padrão (`enable_container_insights = true`):
- Métricas de CPU/memória por task
- Métricas de rede
- Performance de containers

### Métricas no CloudWatch

Acesse: CloudWatch → Container Insights → Performance Monitoring

## 🐛 Debug com ECS Exec

```bash
# 1. Habilite ECS Exec
enable_ecs_exec = true

# 2. Aplique as mudanças
terraform apply

# 3. Liste as tasks
aws ecs list-tasks \
  --cluster usuarios-api-dev-cluster \
  --service-name usuarios-api-dev-service

# 4. Conecte na task
aws ecs execute-command \
  --cluster usuarios-api-dev-cluster \
  --task <task-id-completo> \
  --container usuarios-api \
  --interactive \
  --command "/bin/sh"
```

## 🔄 Deploy de Nova Versão

### Opção 1: Forçar deploy sem mudar código

```bash
terraform apply -var="force_new_deployment=true"
```

### Opção 2: Atualizar imagem

```hcl
# Em terraform.tfvars
container_image = "123456.dkr.ecr.us-east-1.amazonaws.com/app:v2.0"
```

```bash
terraform apply
```

## 🌍 Múltiplos Ambientes

### Opção 1: Workspaces

```bash
terraform workspace new dev
terraform workspace new stg
terraform workspace new prd

terraform workspace select dev
terraform apply -var="environment=dev"
```

### Opção 2: Diretórios separados

```
fargate/
├── dev/
│   ├── main.tf -> ../template/main.tf
│   └── terraform.tfvars
├── stg/
│   ├── main.tf -> ../template/main.tf
│   └── terraform.tfvars
└── prd/
    ├── main.tf -> ../template/main.tf
    └── terraform.tfvars
```

## 🧹 Limpeza

```bash
# Destruir todos os recursos
terraform destroy

# Confirmar com: yes
```

## ⚠️ Notas Importantes

1. **Subnets Privadas**: Tasks ECS devem rodar em subnets privadas com NAT Gateway para acesso à internet

2. **Security Groups**: O template cria SGs automaticamente, mas você pode customizar via `ecs_tasks_ingress_rules`

3. **Custos**: 
   - Fargate: ~$14/mês por task (256 CPU, 512 MB)
   - ALB: ~$16/mês + tráfego
   - NAT Gateway: ~$32/mês

4. **Backend**: Use S3 backend em produção (veja `backend.tf`)

5. **Secrets**: Nunca coloque secrets em variáveis de ambiente, use AWS Secrets Manager

## 📚 Exemplos de Uso

### Aplicação Web Simples

```hcl
app_name          = "minha-api"
container_image   = "nginx:latest"
container_port    = 80
task_cpu          = 256
task_memory       = 512
desired_count     = 2
enable_load_balancer = true
```

### Worker/Background Job

```hcl
app_name          = "worker-processamento"
container_image   = "meu-worker:latest"
enable_load_balancer = false
desired_count     = 1
```

### Aplicação de Alta Disponibilidade

```hcl
task_cpu                  = 1024
task_memory               = 2048
desired_count             = 4
enable_autoscaling        = true
autoscaling_min_capacity  = 4
autoscaling_max_capacity  = 20
enable_container_insights = true
```

## 🆘 Troubleshooting

### Tasks não iniciam

```bash
# Ver logs do serviço
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name>

# Ver eventos das tasks
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-id>
```

### Health check falhando

1. Verifique se o endpoint `/health` existe
2. Ajuste `health_check_grace_period_seconds`
3. Verifique logs do container

### Erro de pull de imagem ECR

1. Verifique permissões da execution role
2. Confirme que a imagem existe no ECR
3. Verifique se as tasks têm acesso à internet (NAT)

## 📞 Comandos Úteis

```bash
# Listar clusters
aws ecs list-clusters

# Listar serviços
aws ecs list-services --cluster <cluster-name>

# Listar tasks
aws ecs list-tasks --cluster <cluster-name>

# Forçar novo deployment
aws ecs update-service \
  --cluster <cluster-name> \
  --service <service-name> \
  --force-new-deployment

# Ver outputs do Terraform
terraform output

# Destruir apenas um recurso específico
terraform destroy -target=module.ecs_service
```
