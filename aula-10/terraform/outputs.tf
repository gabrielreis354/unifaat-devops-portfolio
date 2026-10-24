output "ec2_public_ip" {
  description = "IP público da EC2 (secret EC2_HOST)"
  value       = aws_instance.api.public_ip
}

output "ec2_instance_id" {
  description = "ID da instância"
  value       = aws_instance.api.id
}

output "security_group_id" {
  description = "ID do Security Group da API"
  value       = aws_security_group.api.id
}

output "ecr_repository_url" {
  description = "URI do repositório ECR"
  value       = aws_ecr_repository.api.repository_url
}
