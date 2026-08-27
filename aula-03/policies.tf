# =====================================================================
# CUSTOM POLICIES — menor privilégio (actions específicas, resources limitados)
# =====================================================================

# 1) Leitura em buckets technova-* — anexada ao group developers
resource "aws_iam_policy" "s3_read" {
  name        = "${local.prefix}-technova-s3-read"
  description = "Leitura (List + Get) restrita aos buckets technova-*"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListTechNovaBuckets"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::technova-*"]
      },
      {
        Sid      = "ReadTechNovaObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::technova-*/*"]
      }
    ]
  })
  tags = local.common_tags
}

# 2) EC2 (describe + start/stop com condition de tag) + S3 read/write — group platform-eng
resource "aws_iam_policy" "ec2_s3_full" {
  name        = "${local.prefix}-technova-ec2-s3-full"
  description = "Gerência de EC2 (start/stop em recursos TechNova) e leitura/escrita em technova-*"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EC2Describe"
        Effect   = "Allow"
        Action   = ["ec2:Describe*"]
        Resource = "*"
      },
      {
        # Só pode ligar/desligar instâncias marcadas como Project=TechNova
        Sid      = "EC2StartStopTaggedOnly"
        Effect   = "Allow"
        Action   = ["ec2:StartInstances", "ec2:StopInstances"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = "TechNova"
          }
        }
      },
      {
        Sid      = "S3ListTechNova"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::technova-*"]
      },
      {
        Sid      = "S3ReadWriteTechNova"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["arn:aws:s3:::technova-*/*"]
      }
    ]
  })
  tags = local.common_tags
}

# 3) Deny explícito de ações destrutivas — anexada ao group developers (proteção extra)
#    Deny sempre prevalece sobre Allow; protege até rafael (que também é platform-eng).
resource "aws_iam_policy" "deny_destructive" {
  name        = "${local.prefix}-technova-deny-destructive"
  description = "Bloqueia ações destrutivas (Delete/Terminate) mesmo que outra policy permita"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDestructiveActions"
        Effect = "Deny"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteBucket",
          "ec2:TerminateInstances",
          "iam:DeleteUser",
          "iam:DeleteRole",
          "iam:DeletePolicy",
          "rds:DeleteDBInstance"
        ]
        Resource = "*"
      }
    ]
  })
  tags = local.common_tags
}

# =====================================================================
# ATTACHMENTS — vínculo policy ↔ group
# =====================================================================

resource "aws_iam_group_policy_attachment" "developers_s3_read" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_group_policy_attachment" "developers_deny_destructive" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.deny_destructive.arn
}

resource "aws_iam_group_policy_attachment" "platform_ec2_s3_full" {
  group      = aws_iam_group.platform_eng.name
  policy_arn = aws_iam_policy.ec2_s3_full.arn
}
