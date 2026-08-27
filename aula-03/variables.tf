# Variáveis reutilizáveis do projeto
variable "aws_region" {
  description = "Região AWS onde os recursos IAM serão gerenciados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (usado em tags)"
  type        = string
  default     = "TechNova"
}

variable "environment" {
  description = "Ambiente de execução (lab, staging, prod)"
  type        = string
  default     = "lab"
}

variable "aluno" {
  description = "Nome completo do aluno (usado em tags)"
  type        = string
  default     = "Gabriel Reis Cunha"
}

variable "ra" {
  description = "RA do aluno — prefixo de todos os recursos para evitar conflito na conta compartilhada"
  type        = string
  default     = "6325149"
}
