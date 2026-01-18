terraform {
  backend "s3" {
    bucket = "projeto-golang"
    key    = "cadastro-usuarios/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-lock-table-dia-02"
  }
}
