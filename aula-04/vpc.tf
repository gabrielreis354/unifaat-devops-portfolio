# vpc.tf - Rede Multi-AZ da TechNova (VPC, subnets, IGW, route tables)

# Descobre as AZs disponiveis na regiao e usa as 2 primeiras.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # 2 subnets publicas + 2 privadas, distribuidas em 2 AZs.
  public_subnets = {
    "public-1" = { cidr = "10.0.1.0/24", az = local.azs[0] }
    "public-2" = { cidr = "10.0.3.0/24", az = local.azs[1] }
  }
  private_subnets = {
    "private-1" = { cidr = "10.0.2.0/24", az = local.azs[0] }
    "private-2" = { cidr = "10.0.4.0/24", az = local.azs[1] }
  }
}

# =============================================================
# VPC
# =============================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# =============================================================
# SUBNETS
# =============================================================
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${each.key}"
    Type = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  # Sem map_public_ip_on_launch -> instancias aqui nao recebem IP publico.

  tags = {
    Name = "${var.project_name}-${each.key}"
    Type = "private"
  }
}

# =============================================================
# INTERNET GATEWAY
# =============================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# =============================================================
# ROUTE TABLES
# =============================================================
# Route Table publica: rota default para a internet via IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associa a Route Table publica as DUAS subnets publicas.
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# As subnets privadas usam a Route Table padrao da VPC (somente rota local,
# sem saida para a internet) - nada a declarar.
