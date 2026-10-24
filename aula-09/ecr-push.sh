#!/usr/bin/env bash
# Build e push da technova-api para o Amazon ECR (AWS Academy Learner Lab).
#
# Uso:
#   ./aula-09/ecr-push.sh              # cria o repo (se preciso), builda e publica
#   ./aula-09/ecr-push.sh --print-tags # só mostra as tags que seriam publicadas (sem AWS/Docker)
#
# Tags: sha-<commit curto> e latest sempre; se o HEAD tem uma git tag vX.Y.Z,
# também X.Y.Z, X.Y e X.
set -euo pipefail

REGION="us-east-1"
REPO="technova-api"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT="$SCRIPT_DIR/technova-api"

# Tag semver (vX.Y.Z) que aponta para o HEAD; vazio se não houver.
# GIT_TAG permite simular uma tag (usado para testar sem criar tag no git).
semver_tag() {
  if [ -n "${GIT_TAG:-}" ]; then
    printf '%s\n' "$GIT_TAG"
    return
  fi
  git -C "$SCRIPT_DIR" tag --points-at HEAD \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true
}

# Imprime uma tag por linha: sha-xxxxxxx, latest e, se houver, X.Y.Z, X.Y, X.
compute_tags() {
  local sha tag version
  sha="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)"
  printf 'sha-%s\nlatest\n' "$sha"
  tag="$(semver_tag)"
  if [ -n "$tag" ]; then
    version="${tag#v}"
    printf '%s\n%s\n%s\n' "$version" "${version%.*}" "${version%%.*}"
  fi
}

if [ "${1:-}" = "--print-tags" ]; then
  compute_tags
  exit 0
fi

# ---- Identidade: sessão válida e nunca root ----
if ! IDENTITY_ARN="$(aws sts get-caller-identity --query Arn --output text 2>&1)"; then
  echo "ERRO: credenciais AWS inválidas ou expiradas. Reabra o Learner Lab (Start Lab)" >&2
  echo "      e recarregue as credenciais em ~/.aws/credentials." >&2
  exit 1
fi
case "$IDENTITY_ARN" in
  *:root) echo "ERRO: identidade root não é permitida ($IDENTITY_ARN)." >&2; exit 1 ;;
esac
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
ECR_URI="$REGISTRY/$REPO"
echo "==> Identidade: $IDENTITY_ARN"

# ---- Repositório ECR (idempotente) com scan on push ----
echo "==> Garantindo o repositório ECR ($REPO, $REGION)..."
aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" >/dev/null 2>&1 \
  || aws ecr create-repository --repository-name "$REPO" --region "$REGION" \
       --image-scanning-configuration scanOnPush=true >/dev/null

# Lifecycle policy: expira imagens sem tag após 1 dia e mantém só as 10 mais recentes com tag
LIFECYCLE_POLICY='{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expira imagens sem tag apos 1 dia",
      "selection": {"tagStatus": "untagged", "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 1},
      "action": {"type": "expire"}
    },
    {
      "rulePriority": 2,
      "description": "Mantem apenas as 10 imagens com tag mais recentes",
      "selection": {"tagStatus": "any", "countType": "imageCountMoreThan", "countNumber": 10},
      "action": {"type": "expire"}
    }
  ]
}'
aws ecr put-lifecycle-policy --repository-name "$REPO" --region "$REGION" \
  --lifecycle-policy-text "$LIFECYCLE_POLICY" >/dev/null

# ---- Login no ECR ----
echo "==> Login no ECR..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# ---- Build ----
mapfile -t TAGS < <(compute_tags)
echo "==> Build (contexto: $CONTEXT)..."
docker build -t "$REPO:local" "$CONTEXT"

# ---- Tag e push ----
echo "==> Tags: ${TAGS[*]}"
for tag in "${TAGS[@]}"; do
  docker tag "$REPO:local" "$ECR_URI:$tag"
  docker push "$ECR_URI:$tag"
done

echo "==> Pronto! Imagem publicada:"
for tag in "${TAGS[@]}"; do
  echo "    $ECR_URI:$tag"
done
