# outputs.tf

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB usada para state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}
