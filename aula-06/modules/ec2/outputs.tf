# outputs.tf - modulo ec2

output "instance_id" {
  description = "ID da instancia EC2"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "IP publico da instancia"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "IP privado da instancia"
  value       = aws_instance.this.private_ip
}
