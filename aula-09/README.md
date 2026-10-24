# Aula 09 — Docker Registry (Amazon ECR) e IA no CI/CD

[![CI — TechNova API](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml)
[![AI Code Review](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/ai-review.yml/badge.svg)](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/ai-review.yml)
[![Security Scan](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/security-scan.yml/badge.svg)](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/security-scan.yml)

A TechNova API é publicada no **Amazon ECR** (AWS Academy Learner Lab, `us-east-1`) pelo script [`ecr-push.sh`](ecr-push.sh), e cada Pull Request recebe um **review automático** com quality gate.

## Mapa de arquivos

| Item | Local |
|------|-------|
| Script de build e push para o ECR | [`ecr-push.sh`](ecr-push.sh) |
| Aplicação + Dockerfile multi-stage + `.dockerignore` | [`technova-api/`](technova-api/) |
| Análise (ECR, tagging, padrões, prompt, limitações, Trivy) | [`ia-cicd-analise.md`](ia-cicd-analise.md) |
| Evidências (prints) | [`screenshots/`](screenshots/) |
| AI review + quality gate | [`.github/workflows/ai-review.yml`](../.github/workflows/ai-review.yml) |
| Script de análise e testes | [`.github/scripts/`](../.github/scripts/) |
| Security scan (bônus) | [`.github/workflows/security-scan.yml`](../.github/workflows/security-scan.yml) |
| CI da API (lint → test → build → push-image no ghcr.io, complemento) | [`.github/workflows/ci-aula08.yml`](../.github/workflows/ci-aula08.yml) |

> Os workflows ficam em `.github/` na **raiz** do repositório porque o GitHub só executa workflows de lá (decisão acordada com o professor). `ci-aula08.yml` é o CI evoluído a cada aula; o push para o ghcr.io é um complemento, não o registry da entrega.

## Como executar o `ecr-push.sh`

Pré-requisitos: AWS CLI v2, Docker, Git, e uma sessão ativa do Learner Lab (**Start Lab**, depois copie as credenciais de *AWS Details → AWS CLI* para `~/.aws/credentials`, com `aws_session_token`).

```bash
export AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity            # deve ser assumed-role/voclabs (nunca root)

./aula-09/ecr-push.sh --print-tags     # só mostra as tags, sem AWS/Docker
./aula-09/ecr-push.sh                  # cria o repo (se preciso), builda e publica
```

O script: confere a identidade (aborta se expirou ou se for root) → garante o repositório `technova-api` com *scan on push* → aplica a *lifecycle policy* → `aws ecr get-login-password | docker login` → build → tags → push.

### Tags publicadas

| Situação | Tags |
|----------|------|
| qualquer commit | `sha-xxxxxxx`, `latest` |
| `HEAD` com git tag `v1.2.3` | também `1.2.3`, `1.2`, `1` |

### Pull e rollback

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI=$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/technova-api
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"

docker run -d --name technova -p 3000:3000 $ECR_URI:1.0.1 && curl localhost:3000/health
docker rm -f technova && docker run -d --name technova -p 3000:3000 $ECR_URI:1.0.0   # rollback
```

> **Custos:** o repositório ECR é removido ao final da sessão (`aws ecr delete-repository --repository-name technova-api --region us-east-1 --force`). As evidências ficam em `screenshots/` e no `ia-cicd-analise.md`.

## Testes locais

```bash
cd aula-09/technova-api && npm ci && npm run lint && npm run test:ci
docker build -t technova-api:local aula-09/technova-api
node --test .github/scripts/ai-review.test.js     # 28 testes do AI review
git diff main...HEAD > /tmp/pr-diff.txt && node .github/scripts/ai-review.js
```

## Quality gate

| Severidade | Resultado no PR |
|:----------:|-----------------|
| 🔴 CRITICAL | comentário + check **vermelho** (`exit 1`) |
| 🟡 WARNING / 🔵 INFO | comentário + check verde |
