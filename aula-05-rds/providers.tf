# providers.tf - Terraform, backend remoto (S3 + DynamoDB) e provider AWS

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto: state no S3 com lock no DynamoDB.
  # O bucket e criado pelo aula-05-backend/bootstrap.sh (o SCP do Learner Lab
  # impede gerenciar aws_s3_bucket via Terraform); a tabela DynamoDB vem do
  # `terraform apply` em aula-05-backend/.
  backend "s3" {
    bucket         = "technova-terraform-state-54600b3e83155696"
    key            = "aula-05/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "technova-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
}
