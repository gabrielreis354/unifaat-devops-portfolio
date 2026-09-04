# security-groups.tf - Firewalls virtuais (menor privilegio)

# Security Group da API (EC2 na subnet publica): SSH + porta 3000.
resource "aws_security_group" "api" {
  name        = "${var.project_name}-api-sg"
  description = "API TechNova - permite SSH (22) e HTTP da API (3000)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Em producao: restringir ao IP do administrador.
  }

  ingress {
    description = "API Node.js"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-api-sg"
  }
}

# Security Group do banco (futuro): PostgreSQL apenas de dentro da VPC.
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Banco de dados TechNova - PostgreSQL apenas da VPC interna"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Somente trafego interno da VPC (10.0.0.0/16).
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}
