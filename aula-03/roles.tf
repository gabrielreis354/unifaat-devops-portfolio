# =====================================================================
# SERVICE ROLE — EC2 assume a role para acessar o bucket de dados da app
# =====================================================================

# Trust policy: apenas o serviço EC2 pode assumir esta role
resource "aws_iam_role" "ec2_role" {
  name = "${local.prefix}-technova-ec2-role"
  path = "/technova/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Permissions policy da role: read/write restrito ao bucket technova-app-data-*
resource "aws_iam_policy" "ec2_app_data" {
  name        = "${local.prefix}-technova-ec2-app-data"
  description = "Read/Write da aplicação restrito aos buckets technova-app-data-*"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AppDataList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::technova-app-data-*"]
      },
      {
        Sid      = "AppDataReadWrite"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["arn:aws:s3:::technova-app-data-*/*"]
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_app_data" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_app_data.arn
}

# Instance profile: o que a instância EC2 realmente anexa para usar a role
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.prefix}-technova-ec2-profile"
  path = "/technova/"
  role = aws_iam_role.ec2_role.name
  tags = local.common_tags
}
