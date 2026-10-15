# Aula 09 — Docker Registry (ghcr.io) e IA no CI/CD

[![CI — TechNova API](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml)
[![AI Code Review](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/ai-review.yml/badge.svg)](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/ai-review.yml)
[![Security Scan](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/security-scan.yml/badge.svg)](https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/workflows/security-scan.yml)

A TechNova API passa a **publicar a imagem Docker no GitHub Container Registry** e cada Pull Request recebe um **review automático** com quality gate.

> A aplicação não foi copiada para cá: ela evolui em [`aula-08/technova-api/`](../aula-08/technova-api/) (decisão do professor: cada aula precisa ter a versão correta do projeto). Os workflows ficam em `.github/workflows/` na raiz porque o GitHub só executa workflows de lá.

| Item | Local |
|------|-------|
| CI: lint → test → build → push-image | [`.github/workflows/ci-aula08.yml`](../.github/workflows/ci-aula08.yml) |
| AI review + quality gate | [`.github/workflows/ai-review.yml`](../.github/workflows/ai-review.yml) |
| Script de análise e testes | [`.github/scripts/`](../.github/scripts/) |
| Security scan | [`.github/workflows/security-scan.yml`](../.github/workflows/security-scan.yml) |
| Dockerfile multi-stage | [`aula-08/technova-api/Dockerfile`](../aula-08/technova-api/Dockerfile) |
| Análise (tagging, padrões, prompt, limitações) | [`ia-cicd-analise.md`](ia-cicd-analise.md) |
| Evidências | [`screenshots/`](screenshots/) |

Imagem: `ghcr.io/gabrielreis354/technova-api`

## Tags publicadas

| Evento | Tags |
|--------|------|
| push na `main` | `sha-xxxxxxx`, `latest` |
| git tag `v1.2.3` | `1.2.3`, `1.2`, `1` |
| pull request | nenhuma (não publica) |

## Como testar

```bash
# Usar a imagem publicada (qualquer máquina com Docker)
docker pull ghcr.io/gabrielreis354/technova-api:1.0.1
docker run -d --name technova -p 3000:3000 ghcr.io/gabrielreis354/technova-api:1.0.1
curl http://localhost:3000/health
docker rm -f technova

# Rollback para a versão anterior
docker run -d --name technova -p 3000:3000 ghcr.io/gabrielreis354/technova-api:1.0.0

# Publicar uma nova versão: criar a tag semver e enviar
git tag v1.0.2 -m "Release 1.0.2" && git push origin v1.0.2

# Testar o AI review localmente (27 testes) e rodá-lo sobre o seu diff
node --test .github/scripts/ai-review.test.js
git diff main...HEAD > /tmp/pr-diff.txt && node .github/scripts/ai-review.js
```

## Quality gate

| Severidade | Resultado no PR |
|:----------:|-----------------|
| 🔴 CRITICAL | comentário + check **vermelho** (`exit 1`) |
| 🟡 WARNING / 🔵 INFO | comentário + check verde |
