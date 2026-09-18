# variables.tf - modulo ec2

variable "instance_name" {
  description = "Nome da instancia EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instancia"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID para a instancia (resolvida fora do modulo, no ambiente)"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet onde a instancia sera criada"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de Security Group IDs"
  type        = list(string)
}

variable "key_name" {
  description = "Nome do key pair para SSH (pre-requisito externo, nao criado pelo modulo)"
  type        = string
}

variable "user_data" {
  description = "User data script (opcional)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto para tags"
  type        = string
}
