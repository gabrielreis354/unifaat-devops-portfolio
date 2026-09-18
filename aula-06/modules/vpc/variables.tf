# variables.tf - modulo vpc

variable "vpc_cidr" {
  description = "CIDR block principal da VPC"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags e nomes"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "subnets" {
  description = "Mapa de subnets a serem criadas (chave = nome da subnet)"
  type = map(object({
    cidr = string
    az   = string
    type = string # "public" ou "private"
  }))
}
