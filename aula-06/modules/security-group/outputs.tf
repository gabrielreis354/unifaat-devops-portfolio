# outputs.tf - modulo security-group

output "sg_id" {
  description = "ID do Security Group criado"
  value       = aws_security_group.this.id
}

output "sg_name" {
  description = "Nome do Security Group"
  value       = aws_security_group.this.name
}
