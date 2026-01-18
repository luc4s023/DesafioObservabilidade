# Deploy ECS Fargate com RDS PostgreSQL

Guia para deploy de aplicação Go com banco PostgreSQL no RDS.

## 🗂️ Arquitetura

```
┌─────────────────┐
│   Application   │
│   Load Balancer │ (público)
└────────┬────────┘
         │
    ┌────▼─────┐
    │   ECS    │
    │  Tasks   │ (subnet privada)
    │  (Go App)│
    └────┬─────┘
         │
    ┌────▼─────┐
    │   RDS    │
    │PostgreSQL│ (subnet privada)
    └──────────┘
```

## 📋 Pré-requisitos

- [x] VPC com subnets privadas (mínimo 2 AZs diferentes)
- [x] Subnets públicas para ALB (se usar)
- [x] Imagem Docker no ECR
- [x] Aplicação configurada para ler `POSTGRES_DSN` do ambiente

## 🚀 Passo a Passo

### 1. Preparar seu código Go

Sua aplicação já está configurada corretamente no docker-compose. Certifique-se que ela lê a variável `POSTGRES_DSN`:

```go
// Exemplo de código Go
import (
    "database/sql"
    "os"
    _ "github.com/lib/pq"
)

func main() {
    // Ler connection string do ambiente
    dsn := os.Getenv("POSTGRES_DSN")
    
    db, err := sql.Open("postgres", dsn)
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()
    
    // Verificar conexão
    if err = db.Ping(); err != nil {
        log.Fatal(err)
    }
    
    log.Println("Conectado ao PostgreSQL!")
}
```

### 2. Copiar arquivos do template

```bash
cd /home/l.silva/Documentos/projetos-pessoais/DesafioObservabilidade/fargate/env/sdx

# Copiar arquivos RDS
cp ../../template/rds.tf .
cp ../../template/rds-variables.tf .
cp ../../template/rds-integration-variables.tf .

# Se ainda não tiver, copiar o main.tf atualizado
cp ../../template/main.tf .
```

### 3. Configurar terraform.tfvars

```bash
cp terraform.tfvars.example-with-rds terraform.tfvars
vim terraform.tfvars
```

**Configure os valores essenciais:**

```hcl
# Suas informações de rede
vpc_id             = "vpc-xxxxx"
private_subnet_ids = ["subnet-priv1", "subnet-priv2"] # Para ECS e RDS
public_subnet_ids  = ["subnet-pub1", "subnet-pub2"]   # Para ALB

# Sua imagem no ECR
container_image = "349110610245.dkr.ecr.us-east-1.amazonaws.com/golang-project/cadastro-usuarios:latest"

# Habilitar RDS
create_rds = true

# Subnets do RDS (devem estar em AZs diferentes)
db_subnet_ids = ["subnet-priv1", "subnet-priv2"]

# Database
db_name     = "cadastro_user_db"
db_username = "postgres"
```

### 4. Deploy

```bash
# Inicializar (primeira vez)
terraform init

# Ver o plano
terraform plan

# Aplicar
terraform apply
```

**Tempo estimado:** 10-15 minutos (RDS demora ~10 min para criar)

### 5. Verificar

```bash
# Ver outputs
terraform output

# Connection string estará em Secrets Manager
terraform output db_connection_string_secret_arn

# Ver logs da aplicação
aws logs tail $(terraform output -raw cloudwatch_log_group_name) --follow
```

## 🔐 Como funciona a Connection String

O Terraform cria automaticamente:

1. **Senha aleatória** para o RDS
2. **Secret no AWS Secrets Manager** com a senha
3. **Secret com connection string completa**: `postgres://user:pass@host:5432/db?sslmode=require`
4. **Injeta no container** via variável de ambiente `POSTGRES_DSN`

Sua aplicação simplesmente lê `os.Getenv("POSTGRES_DSN")` e está pronta!

## 📊 Custos Estimados (us-east-1)

### Ambiente de Desenvolvimento (SDX)

| Recurso | Configuração | Custo/mês |
|---------|-------------|-----------|
| RDS PostgreSQL | db.t3.micro (20GB) | ~$15 |
| ECS Fargate | 2 tasks (256 CPU, 512 MB) | ~$28 |
| ALB | 1 ALB + tráfego | ~$16 |
| NAT Gateway | 1 NAT (se necessário) | ~$32 |
| Secrets Manager | 2 secrets | ~$1 |
| **Total** | | **~$92/mês** |

### Ambiente de Produção (PRD)

| Recurso | Configuração | Custo/mês |
|---------|-------------|-----------|
| RDS PostgreSQL | db.t3.small Multi-AZ | ~$60 |
| ECS Fargate | 4 tasks (512 CPU, 1GB) | ~$112 |
| ALB | 1 ALB + tráfego | ~$20 |
| NAT Gateway | 2 NATs (HA) | ~$64 |
| **Total** | | **~$256/mês** |

## 🎛️ Configurações Recomendadas por Ambiente

### Desenvolvimento (dev/sdx)

```hcl
# RDS - Mínimo
db_instance_class          = "db.t3.micro"
db_allocated_storage       = 20
db_backup_retention_period = 1
db_deletion_protection     = false
db_skip_final_snapshot     = true
db_performance_insights_enabled = false

# ECS
task_cpu      = 256
task_memory   = 512
desired_count = 1
enable_autoscaling = false
```

### Staging (stg)

```hcl
# RDS
db_instance_class          = "db.t3.small"
db_allocated_storage       = 20
db_backup_retention_period = 7
db_deletion_protection     = true
db_skip_final_snapshot     = false

# ECS
task_cpu      = 512
task_memory   = 1024
desired_count = 2
enable_autoscaling = true
```

### Produção (prd)

```hcl
# RDS - Alta Disponibilidade
db_instance_class          = "db.t3.medium"
db_allocated_storage       = 100
db_backup_retention_period = 30
db_deletion_protection     = true
db_skip_final_snapshot     = false
db_performance_insights_enabled = true
# Considerar Multi-AZ (adicionar multi_az = true)

# ECS
task_cpu      = 1024
task_memory   = 2048
desired_count = 4
enable_autoscaling = true
autoscaling_max_capacity = 20
```

## 🔧 Customizações

### Migrar dados existentes

Se você já tem um banco PostgreSQL:

```bash
# Exportar do banco antigo
pg_dump -h localhost -U postgres cadastro_user_db > dump.sql

# Importar no RDS
# 1. Obter endpoint
RDS_ENDPOINT=$(terraform output -raw db_instance_address)

# 2. Obter senha do Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw db_password_secret_arn) \
  --query SecretString \
  --output text

# 3. Importar
psql -h $RDS_ENDPOINT -U postgres -d cadastro_user_db -f dump.sql
```

### Conectar de fora (Debug)

Para conectar no RDS de fora da AWS (APENAS DEV):

```hcl
# terraform.tfvars
db_publicly_accessible = true  # ⚠️ NUNCA em produção!
db_allowed_cidr_blocks = ["SEU-IP-PUBLICO/32"]
```

### Usar variáveis separadas ao invés de connection string

```hcl
# terraform.tfvars
db_use_environment_variable = true
```

Isso cria variáveis separadas: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`

Ajuste seu código Go:

```go
host := os.Getenv("DB_HOST")
port := os.Getenv("DB_PORT")
user := os.Getenv("DB_USER")
password := os.Getenv("DB_PASSWORD")
dbname := os.Getenv("DB_NAME")

dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
    host, port, user, password, dbname)
```

## 🐛 Troubleshooting

### ECS tasks não conseguem conectar no RDS

1. **Verificar security groups:**
```bash
# Ver SG do RDS
terraform output db_security_group_id

# Ver SG do ECS
terraform output ecs_tasks_security_group_id

# Confirmar que ECS SG está permitido no RDS SG
```

2. **Verificar logs:**
```bash
aws logs tail /ecs/usuarios-api --follow
```

3. **Verificar secret:**
```bash
# Ver connection string
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw db_connection_string_secret_arn)
```

### RDS está muito lento

1. Habilitar Performance Insights:
```hcl
db_performance_insights_enabled = true
```

2. Ver métricas no console: RDS → Performance Insights

### Alterar senha do RDS

```bash
# Terraform vai recriar automaticamente ao aplicar
terraform taint 'random_password.db_password[0]'
terraform apply
```

## 🧹 Limpeza

```bash
# Atenção: isso vai deletar o RDS!
terraform destroy

# Se tiver deletion_protection = true, primeiro:
terraform apply -var="db_deletion_protection=false"
terraform destroy
```

## ✅ Checklist Pré-Deploy

- [ ] VPC e subnets configuradas corretamente
- [ ] Subnets do RDS em AZs diferentes
- [ ] Aplicação lê `POSTGRES_DSN` do ambiente
- [ ] Imagem Docker no ECR
- [ ] `terraform.tfvars` configurado
- [ ] Backend do Terraform configurado (S3)
- [ ] Endpoint `/health` implementado na aplicação
- [ ] Migrations do banco prontas (se necessário)

## 📚 Próximos Passos

1. **Migrations**: Configure flyway ou golang-migrate
2. **Monitoring**: CloudWatch Alarms para RDS e ECS
3. **Backup**: Teste restore dos snapshots
4. **Read Replicas**: Para escalar leituras (produção)
5. **Multi-AZ**: Para alta disponibilidade (produção)
