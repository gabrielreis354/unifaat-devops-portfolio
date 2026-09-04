# variables.tf - Variaveis do projeto

variable "aws_region" {
  description = "Regiao AWS para criar os recursos"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (prefixo de nomes e tags)"
  type        = string
  default     = "technova"
}

variable "environment" {
  description = "Ambiente (development, staging, production)"
  type        = string
  default     = "development"
}

variable "owner" {
  description = "Responsavel pelos recursos (RA do aluno)"
  type        = string
  default     = "6325149"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "Tipo da instancia EC2 (t2.micro = Free Tier)"
  type        = string
  default     = "t2.micro"
}

# --- IAM / Instance Profile ---
# O AWS Academy Learner Lab (role voclabs) NAO permite criar IAM Role/Profile.
# create_iam_role = true  -> cria Role + Instance Profile (conforme o TF; evidencia via plan)
# create_iam_role = false -> reutiliza um Instance Profile existente (ex.: LabInstanceProfile)
variable "create_iam_role" {
  description = "Se true, cria IAM Role + Instance Profile proprios; se false, usa um existente"
  type        = bool
  default     = true
}

variable "existing_instance_profile" {
  description = "Nome de um Instance Profile ja existente (usado quando create_iam_role = false)"
  type        = string
  default     = "LabInstanceProfile"
}
