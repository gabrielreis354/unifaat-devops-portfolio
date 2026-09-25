# main.tf - Tags comuns e data sources compartilhados pela infra (VPC, RDS, EC2)
#
# Os recursos ficam separados por responsabilidade: vpc.tf, rds.tf, ec2.tf.

locals {
  # Aplicadas em todos os recursos via merge(local.common_tags, { Name = ... })
  common_tags = {
    Project = var.project_name
    Aula    = "05"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
