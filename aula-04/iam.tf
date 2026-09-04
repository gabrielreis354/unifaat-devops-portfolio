# iam.tf - Service role + Instance Profile para a EC2 (acesso S3 read-only)
#
# Gated por var.create_iam_role: o TF pede a criacao da Role/Profile (evidencia
# via plan). No Learner Lab, onde criar Role da 403, use create_iam_role = false
# para reutilizar o LabInstanceProfile existente (ver locals em ec2.tf).

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  count = var.create_iam_role ? 1 : 0

  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_s3_read" {
  count = var.create_iam_role ? 1 : 0

  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role[0].name

  tags = {
    Name = "${var.project_name}-ec2-profile"
  }
}
