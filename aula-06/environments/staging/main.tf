# main.tf - ambiente dev (root module)
# Composicao: VPC -> Security Groups -> EC2 / RDS

module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  environment  = var.environment
  subnets      = var.subnets
}

module "api_sg" {
  source = "../../modules/security-group"

  name         = "${var.project_name}-${var.environment}-api-sg"
  description  = "Security Group para a API - HTTP e SSH"
  vpc_id       = module.vpc.vpc_id # <- composicao: output do modulo vpc
  environment  = var.environment
  project_name = var.project_name

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from anywhere"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "SSH from anywhere"
    }
  ]
}

module "rds_sg" {
  source = "../../modules/security-group"

  name         = "${var.project_name}-${var.environment}-rds-sg"
  description  = "Security Group para o RDS - PostgreSQL apenas da VPC"
  vpc_id       = module.vpc.vpc_id # <- composicao: output do modulo vpc
  environment  = var.environment
  project_name = var.project_name

  ingress_rules = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
      description = "PostgreSQL from VPC"
    }
  ]
}

# AMI Amazon Linux 2023 mais recente (resolvida aqui, passada ao modulo ec2)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "api_server" {
  source = "../../modules/ec2"

  instance_name = "${var.project_name}-${var.environment}-api"
  instance_type = "t2.micro"
  ami_id        = data.aws_ami.amazon_linux.id
  subnet_id     = module.vpc.public_subnet_ids[0] # <- composicao: output do modulo vpc

  security_group_ids = [module.api_sg.sg_id] # <- composicao: output do modulo security-group

  key_name     = var.key_name
  environment  = var.environment
  project_name = var.project_name
}

module "database" {
  source = "../../modules/rds"

  db_name     = "technova_${var.environment}"
  db_username = var.db_username
  db_password = var.db_password

  subnet_ids         = module.vpc.private_subnet_ids # <- composicao: output do modulo vpc
  security_group_ids = [module.rds_sg.sg_id]         # <- composicao: output do modulo security-group

  environment  = var.environment
  project_name = var.project_name
}
