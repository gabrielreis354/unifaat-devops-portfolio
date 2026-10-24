#!/bin/bash
# Prepara a EC2 para receber deploys: Docker + AWS CLI v2 (login no ECR via instance profile)
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io unzip curl
systemctl enable --now docker
usermod -aG docker ubuntu

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
