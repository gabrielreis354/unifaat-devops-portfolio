# Locals: prefixo por RA e tags obrigatórias aplicadas a todos os recursos que suportam tags
locals {
  prefix = var.ra

  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Aluno       = var.aluno
    RA          = var.ra
    Disciplina  = "DevOps - UniFAAT 2026-2"
    Aula        = "03"
    Environment = var.environment
  }
}

# =====================================================================
# GROUPS — separação de responsabilidades
# (Obs.: aws_iam_group não suporta tags; as tags vão nos users/policies/roles)
# =====================================================================

# Devs: acesso de leitura ao S3
resource "aws_iam_group" "developers" {
  name = "${local.prefix}-technova-developers"
  path = "/technova/"
}

# Engenharia de plataforma: gerencia EC2 + S3 (acesso completo)
resource "aws_iam_group" "platform_eng" {
  name = "${local.prefix}-technova-platform-eng"
  path = "/technova/"
}

# =====================================================================
# USERS — distribuídos nos groups
# =====================================================================

resource "aws_iam_user" "juliana_dev" {
  name = "${local.prefix}-juliana-dev"
  path = "/technova/"
  tags = local.common_tags
}

resource "aws_iam_user" "rafael_platform" {
  name = "${local.prefix}-rafael-platform"
  path = "/technova/"
  tags = local.common_tags
}

resource "aws_iam_user" "lucas_intern" {
  name = "${local.prefix}-lucas-intern"
  path = "/technova/"
  tags = local.common_tags
}

# =====================================================================
# MEMBERSHIPS — quem pertence a cada group
# =====================================================================

# developers: juliana, rafael e lucas
resource "aws_iam_group_membership" "developers" {
  name  = "${local.prefix}-developers-membership"
  group = aws_iam_group.developers.name
  users = [
    aws_iam_user.juliana_dev.name,
    aws_iam_user.rafael_platform.name,
    aws_iam_user.lucas_intern.name,
  ]
}

# platform-eng: apenas rafael (também é dev)
resource "aws_iam_group_membership" "platform_eng" {
  name  = "${local.prefix}-platform-eng-membership"
  group = aws_iam_group.platform_eng.name
  users = [
    aws_iam_user.rafael_platform.name,
  ]
}
