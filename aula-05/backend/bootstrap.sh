#!/usr/bin/env bash
# bootstrap.sh - Cria o bucket S3 que hospeda o terraform.tfstate remoto.
#
# Por que nao e Terraform? O SCP do AWS Academy Learner Lab nega
# s3:GetBucketObjectLockConfiguration, e o recurso aws_s3_bucket do provider
# hashicorp/aws chama essa API em toda leitura/criacao -> falha com AccessDenied.
# As demais chamadas (create-bucket, versioning, encryption, public-access-block)
# sao permitidas, entao criamos o bucket pelo AWS CLI. A tabela DynamoDB de lock
# continua no Terraform (dynamodb.tf).
#
# Uso:  source aws-creds.sh && ./bootstrap.sh
# Idempotente: pode rodar de novo sem problema. Reaproveita o bucket ja anotado
# em backend-bucket.txt, se existir.
set -euo pipefail

REGION="us-east-1"
NAME_FILE="$(dirname "$0")/backend-bucket.txt"

# 1) Nome do bucket (reaproveita ou gera com sufixo aleatorio)
if [[ -f "$NAME_FILE" ]]; then
  BUCKET="$(cat "$NAME_FILE")"
  echo "Reaproveitando bucket de $NAME_FILE: $BUCKET"
else
  BUCKET="technova-terraform-state-$(openssl rand -hex 8)"
  echo "$BUCKET" > "$NAME_FILE"
  echo "Novo bucket: $BUCKET (anotado em $NAME_FILE)"
fi

# 2) Confirma identidade (nunca root)
ARN="$(aws sts get-caller-identity --query Arn --output text)"
case "$ARN" in
  *:root) echo "ERRO: identidade root. Use um usuario/role IAM."; exit 1 ;;
esac
echo "Identidade: $ARN"

# 3) Cria o bucket (ignora se ja existe e e seu)
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket ja existe."
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  echo "Bucket criado."
fi

# 4) Versionamento (rollback do state)
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
echo "Versionamento: Enabled"

# 5) Encriptacao server-side (SSE-KMS com a chave gerenciada aws/s3)
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"},"BucketKeyEnabled":true}]}'
echo "Encriptacao: aws:kms"

# 6) Block Public Access (as 4 protecoes)
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "Block Public Access: 4/4 true"

# 7) Tags (Name, Project, Aula) - o bucket fica fora do Terraform, entao
#    as tags que o default_tags aplicaria sao definidas aqui
aws s3api put-bucket-tagging --bucket "$BUCKET" \
  --tagging "TagSet=[{Key=Name,Value=$BUCKET},{Key=Project,Value=TechNova},{Key=Aula,Value=05},{Key=Purpose,Value=Terraform Remote State}]"
echo "Tags: Name, Project, Aula, Purpose"

# 8) Verificacao
echo
echo "==== VERIFICACAO ===="
aws s3api get-bucket-versioning --bucket "$BUCKET"
aws s3api get-bucket-encryption --bucket "$BUCKET"
aws s3api get-public-access-block --bucket "$BUCKET"
aws s3api get-bucket-tagging --bucket "$BUCKET"

echo
echo "==== Configure o backend \"s3\" em ../providers.tf ===="
cat <<CFG
  backend "s3" {
    bucket         = "$BUCKET"
    key            = "aula-05/terraform.tfstate"
    region         = "$REGION"
    encrypt        = true
    dynamodb_table = "technova-terraform-locks"
  }
CFG
