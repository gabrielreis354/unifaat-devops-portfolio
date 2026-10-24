locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Aula        = "10"
  }
}

# Rede: VPC/subnet default da conta (sem custo extra)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Ubuntu 22.04 LTS (Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Key pair automatizado: só a chave pública vai para o Git; a privada fica no secret EC2_SSH_KEY
resource "aws_key_pair" "deploy" {
  key_name   = "${var.project_name}-deploy-key"
  public_key = file("${path.module}/${var.ssh_public_key_path}")

  tags = merge(local.common_tags, { Name = "${var.project_name}-deploy-key" })
}

resource "aws_security_group" "api" {
  name        = "${var.project_name}-api-sg"
  description = "TechNova API: SSH (deploy) e porta 3000 (app)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH para GitHub Actions runners (IPs variaveis; aceitavel no Lab)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TechNova API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Saida liberada (pull de imagens, ECR)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-api-sg" })
}

# Mudança de infra de demonstração do GitOps (plan no PR, apply no merge)
resource "aws_security_group_rule" "allow_https" {
  count = var.enable_https_rule ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.api.id
  description       = "Allow HTTPS inbound"
}

resource "aws_instance" "api" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.api.id]
  key_name               = aws_key_pair.deploy.key_name
  iam_instance_profile   = var.instance_profile_name

  user_data = file("${path.module}/user_data.sh")

  # user_data só roda no 1º boot; mudar o script recria a instância de forma explícita
  user_data_replace_on_change = true

  tags = merge(local.common_tags, { Name = "${var.project_name}-api" })

  volume_tags = merge(local.common_tags, { Name = "${var.project_name}-api-root" })
}

# Registry das imagens (cd.yml faz push; destroy remove mesmo com imagens)
resource "aws_ecr_repository" "api" {
  name         = "technova-api"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, { Name = "technova-api" })
}
