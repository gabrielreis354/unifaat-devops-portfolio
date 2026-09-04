# ec2.tf - Instancia EC2 com a API TechNova (Key Pair via Terraform, User Data)

# AMI mais recente do Amazon Linux 2023 (x86_64) - via data source, sem ID fixo.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Key Pair criado via Terraform: gera o par e salva a chave privada localmente.
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

# Salva a chave privada em disco (0400) para uso no SSH. Gitignore: *.pem.
resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0400"
}

locals {
  # Usa o Instance Profile criado pelo Terraform ou um existente (Learner Lab).
  instance_profile_name = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].name : var.existing_instance_profile

  # Uma das subnets publicas para hospedar a API.
  api_subnet_id = aws_subnet.public["public-1"].id
}

resource "aws_instance" "api" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = local.api_subnet_id
  vpc_security_group_ids = [aws_security_group.api.id]
  key_name               = aws_key_pair.main.key_name
  iam_instance_profile   = local.instance_profile_name
  user_data              = file("${path.module}/user_data.sh")

  root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}
