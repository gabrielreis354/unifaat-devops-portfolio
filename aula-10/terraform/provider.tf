terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend parcial: o bucket (technova-tfstate-<ACCOUNT_ID>) é informado no init:
  #   terraform init -backend-config="bucket=technova-tfstate-<ACCOUNT_ID>"
  # O bucket é criado por bootstrap.sh (a SCP do Learner Lab bloqueia aws_s3_bucket no Terraform).
  backend "s3" {
    key          = "aula-10/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # lock nativo no S3 (sem DynamoDB)
  }
}

provider "aws" {
  region = var.aws_region
}
