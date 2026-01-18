################################################################################
# Backend Configuration - Terraform State
################################################################################

# IMPORTANTE: Configure o backend antes de executar terraform init
# 
# 1. Crie um bucket S3 para armazenar o state
# 2. Crie uma tabela DynamoDB para lock (opcional mas recomendado)
# 3. Descomente e ajuste as configurações abaixo

# terraform {
#   backend "s3" {
#     # Bucket S3 para armazenar o state
#     bucket = "meu-projeto-terraform-state"
#     
#     # Chave do state file (ajuste conforme seu ambiente)
#     key = "fargate/dev/terraform.tfstate"
#     
#     # Região do bucket
#     region = "us-east-1"
#     
#     # Tabela DynamoDB para lock (previne conflitos em deploys simultâneos)
#     dynamodb_table = "terraform-state-lock"
#     
#     # Encriptação do state
#     encrypt = true
#     
#     # KMS key para encriptar o state (opcional)
#     # kms_key_id = "arn:aws:kms:us-east-1:123456789:key/xxxxx"
#   }
# }

################################################################################
# Como criar os recursos do backend:
################################################################################

# 1. Criar bucket S3:
# aws s3api create-bucket \
#   --bucket meu-projeto-terraform-state \
#   --region us-east-1

# 2. Habilitar versionamento:
# aws s3api put-bucket-versioning \
#   --bucket meu-projeto-terraform-state \
#   --versioning-configuration Status=Enabled

# 3. Criar tabela DynamoDB para lock:
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1

################################################################################
# Backend Local (Para desenvolvimento/testes)
################################################################################

# Se preferir usar backend local durante desenvolvimento:
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# LEMBRE-SE: Em produção, SEMPRE use backend remoto (S3)!
