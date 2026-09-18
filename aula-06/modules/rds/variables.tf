# variables.tf - modulo rds

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "db_username" {
  description = "Username do banco de dados RDS"
  type        = string
}

variable "db_password" {
  description = "Password do banco de dados RDS"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "Subnet IDs (privadas) para o DB Subnet Group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security Group IDs para o RDS"
  type        = list(string)
}

variable "instance_class" {
  description = "Classe da instancia RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags"
  type        = string
}
