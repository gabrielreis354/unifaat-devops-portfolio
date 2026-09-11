#!/usr/bin/env bash
# teardown.sh - Esvazia (todas as versoes + delete markers) e apaga o bucket do state.
# Uso:  source aws-creds.sh && ./teardown.sh
# Rode DEPOIS de `terraform destroy` no aula-05-rds e no aula-05-backend.
set -euo pipefail

NAME_FILE="$(dirname "$0")/backend-bucket.txt"
BUCKET="${1:-$(cat "$NAME_FILE" 2>/dev/null || true)}"
[[ -n "${BUCKET:-}" ]] || { echo "Informe o bucket: ./teardown.sh <nome>"; exit 1; }

if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket $BUCKET nao existe mais. Nada a fazer."
  rm -f "$NAME_FILE"
  exit 0
fi

echo "Esvaziando $BUCKET (versoes)..."
aws s3api list-object-versions --bucket "$BUCKET" \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text 2>/dev/null \
  | while read -r key version; do
      [[ -n "$key" ]] && aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$version" >/dev/null
    done

echo "Esvaziando $BUCKET (delete markers)..."
aws s3api list-object-versions --bucket "$BUCKET" \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text 2>/dev/null \
  | while read -r key version; do
      [[ -n "$key" ]] && aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$version" >/dev/null
    done

aws s3api delete-bucket --bucket "$BUCKET"
rm -f "$NAME_FILE"
echo "Bucket $BUCKET removido."
