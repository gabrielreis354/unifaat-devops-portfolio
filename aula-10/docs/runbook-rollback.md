# Runbook: Rollback de Deploy (Recreate via ECR)

Cada deploy publica a imagem com a tag `sha-<7 primeiros chars do commit>` no ECR (`technova-api`).
Rollback = recriar o container com uma tag anterior conhecida.

## Quando usar
- Deploy causou erros na aplicação.
- Health check passa, mas a funcionalidade está quebrada.
- Bug crítico detectado depois do deploy.

## Procedimento
1. **Escolher a tag estável** (mais recente antes do problema):
   ```bash
   aws ecr describe-images --repository-name technova-api --region us-east-1 \
     --query 'sort_by(imageDetails,&imagePushedAt)[].[imageTags,imagePushedAt]' --output table
   git log --oneline -5 -- aula-10/technova-api   # mapear SHA ↔ commit
   ```
2. **Entrar na EC2:** `ssh -i technova-deploy.key ubuntu@<EC2_HOST>`
3. **Login no ECR antes do pull** (usa o instance profile da EC2; sem credenciais locais):
   ```bash
   REGISTRY=<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
   aws ecr get-login-password --region us-east-1 \
     | docker login --username AWS --password-stdin "$REGISTRY"
   ```
4. **Recreate com a tag anterior:**
   ```bash
   TAG=sha-XXXXXXX
   docker pull "$REGISTRY/technova-api:$TAG"
   docker stop technova-api && docker rm technova-api
   docker run -d --name technova-api -p 3000:3000 --restart unless-stopped \
     -e NODE_ENV=production -e GITHUB_SHA="$TAG" \
     -e DEPLOY_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     "$REGISTRY/technova-api:$TAG"
   ```
5. **Verificar:** `curl http://localhost:3000/health` (200) e `curl http://localhost:3000/version`.
6. **Corrigir no Git:** abrir PR com `git revert` do commit problemático; sem isso o próximo push na `main` reimplanta a versão ruim.
7. Comunicar o time.

> Se `docker login` falhar com `ExpiredToken`: a sessão do Learner Lab expirou. Reabra o Lab e atualize os 3 secrets AWS.

## Execução real (teste do runbook)
_Preenchido após o teste — ver `gitops-cd-analise.md`, seção “Evidência do rollback”._
