variable "aws_region" {
  description = "Região AWS (Learner Lab usa us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (usado em tags e nomes)"
  type        = string
  default     = "technova"
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "prod"
}

variable "instance_type" {
  description = "Tipo da EC2 (free-tier)"
  type        = string
  default     = "t3.micro"
}

variable "instance_profile_name" {
  description = "Instance profile pré-existente do Learner Lab (nunca criar IAM próprio)"
  type        = string
  default     = "LabInstanceProfile"
}

variable "ssh_public_key_path" {
  description = "Caminho da chave pública SSH usada no aws_key_pair"
  type        = string
  default     = "technova-deploy.pub"
}

variable "enable_https_rule" {
  description = "Libera HTTPS (443) no Security Group — mudança usada para demonstrar o fluxo GitOps"
  type        = bool
  default     = false
}
