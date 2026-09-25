# main.tf - Terraform e provider AWS para a infraestrutura de Remote State
#
# NOTA (AWS Academy Learner Lab): o SCP da conta nega s3:GetBucketObjectLockConfiguration,
# chamada que o recurso aws_s3_bucket do provider hashicorp/aws executa em toda
# leitura/criacao. Por isso o BUCKET S3 do state e criado pelo bootstrap.sh (aws CLI),
# e a tabela de lock (DynamoDB) permanece gerenciada aqui pelo Terraform.

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

  default_tags {
    tags = {
      Project = "TechNova"
      Aula    = "05"
      Purpose = "Terraform Remote State"
    }
  }
}
