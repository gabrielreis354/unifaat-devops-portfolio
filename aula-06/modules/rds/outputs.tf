# outputs.tf - modulo rds

output "db_endpoint" {
  description = "Endpoint de conexao do RDS (host:porta)"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.main.db_name
}

output "db_port" {
  description = "Porta do RDS"
  value       = aws_db_instance.main.port
}
