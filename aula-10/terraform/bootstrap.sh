#!/usr/bin/env bash
# Cria (idempotente) o bucket do state remoto via AWS CLI.
# Motivo: no Learner Lab a SCP bloqueia s3:GetBucketObjectLockConfiguration e o
# recurso aws_s3_bucket do Terraform falha no refresh.
set -euo pipefail

REGION="us-east-1"
ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null) \
  || { echo "ERRO: sessão AWS inválida/expirada (reabra o Learner Lab)." >&2; exit 1; }
case "$ARN" in
  *":root") echo "ERRO: identidade root — use um usuário IAM/voclabs." >&2; exit 1 ;;
esac

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="technova-tfstate-${ACCOUNT_ID}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket $BUCKET já existe."
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging \
  'TagSet=[{Key=Project,Value=technova},{Key=Aula,Value=10},{Key=ManagedBy,Value=bootstrap.sh}]'

echo "OK: bucket de state = $BUCKET"
echo "Init: terraform init -backend-config=\"bucket=$BUCKET\""
