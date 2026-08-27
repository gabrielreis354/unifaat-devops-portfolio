# Outputs — facilitam auditoria e integração
output "iam_users" {
  description = "Nomes dos IAM users criados"
  value = [
    aws_iam_user.juliana_dev.name,
    aws_iam_user.rafael_platform.name,
    aws_iam_user.lucas_intern.name,
  ]
}

output "iam_groups" {
  description = "Nomes dos IAM groups criados"
  value = [
    aws_iam_group.developers.name,
    aws_iam_group.platform_eng.name,
  ]
}

output "policy_arns" {
  description = "ARNs das custom policies"
  value = {
    s3_read          = aws_iam_policy.s3_read.arn
    ec2_s3_full      = aws_iam_policy.ec2_s3_full.arn
    deny_destructive = aws_iam_policy.deny_destructive.arn
    ec2_app_data     = aws_iam_policy.ec2_app_data.arn
  }
}

output "ec2_role_arn" {
  description = "ARN da service role do EC2"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile" {
  description = "Nome do instance profile associado à role"
  value       = aws_iam_instance_profile.ec2_profile.name
}
