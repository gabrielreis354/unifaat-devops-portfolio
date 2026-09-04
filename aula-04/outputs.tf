# outputs.tf - Valores exportados apos o apply

output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = [for s in aws_subnet.private : s.id]
}

output "api_security_group_id" {
  description = "ID do Security Group da API"
  value       = aws_security_group.api.id
}

output "db_security_group_id" {
  description = "ID do Security Group do banco"
  value       = aws_security_group.db.id
}

output "ec2_public_ip" {
  description = "IP publico da instancia EC2"
  value       = aws_instance.api.public_ip
}

output "api_url" {
  description = "URL da API TechNova"
  value       = "http://${aws_instance.api.public_ip}:3000"
}

output "ssh_command" {
  description = "Comando SSH para conectar na instancia"
  value       = "ssh -i ${var.project_name}-key.pem ec2-user@${aws_instance.api.public_ip}"
}
