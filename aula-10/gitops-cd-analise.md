# GitOps + CD — Análise (Aula 10)

## 1. Fluxo GitOps: por que plan no PR e apply no merge
- **Plan no PR** (`terraform-plan.yml`): é o *diff de infraestrutura*. O revisor vê o que será criado/alterado/**destruído** antes de aprovar. O comentário é atualizado a cada push (não duplica) e avisa quando o plan destrói/recria recursos. Se `fmt`, `validate` ou `plan` falham, o workflow falha.
- **Apply no merge** (`terraform-apply.yml`): o merge na `main` **é** a aprovação; o `-auto-approve` é seguro porque o plan já foi revisado e não há terminal no CI. Só o pipeline aplica — ninguém roda `apply` no laptop.
- **Git como auditoria:** quem, quando e o quê ficam no histórico; rollback de infra = `git revert` + novo PR. O state fica remoto no S3 (versionado, com lock), compartilhado entre PR e merge.
- `concurrency` sem cancelamento no apply evita dois applies simultâneos corromperem o state.
- Destroy é um workflow à parte (`terraform-destroy.yml`), manual e com confirmação digitada.

## 2. Autenticação no Learner Lab × produção
- **No Lab:** as 3 credenciais temporárias da sessão (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) ficam como GitHub Secrets e entram em `aws-actions/configure-aws-credentials@v4`. Expiram quando a sessão fecha — é preciso atualizar os secrets a cada sessão (erro típico: `ExpiredToken`).
- **Em produção o ideal é OIDC + role IAM:** o GitHub emite um token por execução, a AWS o troca por credenciais de minutos via `role-to-assume`; nenhuma chave fica armazenada, e a role limita por repositório/branch.
- **Por que o Lab não permite:** exige criar `aws_iam_openid_connect_provider` e roles IAM, operações bloqueadas para o `voclabs`. Por isso **não há `oidc.tf`** neste projeto. A diferença é de permissão disponível, não de conceito.
- A EC2 não recebe credenciais de sessão: usa o `LabInstanceProfile` (role pré-existente) para o login no ECR, o que também evita expirar no meio de um deploy.

## 3. Estratégia Recreate
`docker stop → rm → pull → run` no mesmo servidor.
- **Prós:** simples, sem infraestrutura extra, custo zero a mais, fácil de entender e depurar.
- **Contras:** downtime de segundos a cada deploy; se a nova versão falhar, o serviço fica fora até o rollback; sem validação prévia da versão nova com tráfego real.
- **Quando usar:** apps internas, baixa criticidade, 1 servidor, janela de manutenção aceitável (ex.: Admin Dashboard, jobs). **Não** serve para API pública com SLA alto — aí Blue-Green/Canary (aulas 11 e 12).
- O pipeline mitiga o risco: só chega ao deploy se lint e testes passam; o health check falha o job se a app não responder (e confere em `/version` o commit implantado).

## 4. Continuous Delivery × Continuous Deployment
| | Delivery | Deployment |
|---|---|---|
| Deploy em produção | Pronto para ir, com **aprovação manual** | **Automático** a cada merge testado |
| Indicado para | Compliance, releases planejados | SaaS/startups com iteração rápida |

Este projeto faz **Continuous Deployment** (todo push na `main` com mudança na app vai ao ar). Para virar Delivery basta adicionar *Required reviewers* no GitHub Environment `production`.

## 5. Rollback
Imagens têm tag `sha-<commit>` (rastreabilidade commit ↔ ECR ↔ deploy); `latest` não serve para rollback. Procedimento completo, incluindo **login no ECR antes do pull**, em [`docs/runbook-rollback.md`](docs/runbook-rollback.md). Infra: `git revert` do PR de Terraform → novo plan/apply.

## 6. Limitações e o que melhoraria
- Credenciais de sessão expiram e são manuais → OIDC + role em produção.
- SSH aberto a `0.0.0.0/0` (IPs dos runners variam) → usar AWS SSM Session Manager ou ranges de `api.github.com/meta`.
- Recreate tem downtime → Blue-Green/Canary com load balancer.
- App exposta em HTTP na porta 3000 → ALB com HTTPS.
- Apply sem aprovação adicional → GitHub Environment com revisores e branch protection com *required checks*.
- `prevent_destroy` não foi aplicado à EC2/ECR (impediria o destroy exigido pela regra de custos do Lab); em produção deve proteger recursos como RDS (`lifecycle { prevent_destroy = true }`).
- Terraform não rastreia mudança de drift fora do PR; um `plan` agendado detectaria divergências.

## Bônus implementados
Comentário do plan atualizado (sem duplicar) · `terraform fmt -check` · deploy com `GITHUB_SHA` no container · aviso de destroy no plan · notificação como comentário no commit · workflow de destroy manual com confirmação · GitHub Environment `production` (deploy) e `destroy`.

## Evidências da execução (Learner Lab, 2026-10-23)

| Etapa | Evidência |
|---|---|
| Plan no PR 1 (infra base: 4 to add) | PR #11 — print `screenshots/plan-pr-comment.png` |
| Apply no merge do PR 1 (4 added) | run `terraform-apply` do merge do PR #11 (outputs: EC2 `i-04fa90bdbb55eb752`, SG `sg-09fb4a0701dfcac12`, ECR) |
| Plan no PR 2 (regra HTTPS: 1 to add, 0 to destroy) | PR #12 |
| Apply no merge do PR 2 | run https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/runs/40049192443 — print `screenshots/apply-success.png` |
| CD completo (lint → test → build → push → deploy) | run https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/runs/40049695435 — print `screenshots/cd-pipeline-green.png` |
| Health check pós-deploy | mesmo run — print `screenshots/health-check-pass.png` (`Health check OK (HTTP 200) na tentativa 1`, `/version` = 1.1.0, commit `64c147f`) |
| Rollback | seção abaixo |
| Destroy | run https://github.com/gabrielreis354/unifaat-devops-portfolio/actions/runs/40050125833 — `Destroy complete! Resources: 5 destroyed.` |

### Observação: primeiro run do CD vermelho
O merge do PR 1 disparou o apply **e** o CD ao mesmo tempo. O deploy falhou com `missing server host` porque o secret `EC2_HOST` só pode ser criado depois do primeiro apply (o IP vem do output). Depois de cadastrar o secret, reexecutei apenas o job que falhou e o pipeline fechou verde (health check OK, `/version` com o commit `d88b6d4`). Em um ambiente definitivo o IP seria fixo (Elastic IP/DNS) e o secret já existiria.

### Tags (ressalva de entregas anteriores) — `aws ec2 describe-tags` / `aws ecr list-tags-for-resource`
```
instance         Aula=10
instance         Environment=prod
instance         ManagedBy=terraform
instance         Name=technova-api
instance         Project=technova
key-pair         Aula=10
key-pair         Environment=prod
key-pair         ManagedBy=terraform
key-pair         Name=technova-deploy-key
key-pair         Project=technova
security-group   Aula=10
security-group   Environment=prod
security-group   ManagedBy=terraform
security-group   Name=technova-api-sg
security-group   Project=technova
volume           Aula=10
volume           Environment=prod
volume           ManagedBy=terraform
volume           Name=technova-api-root
volume           Project=technova

ECR technova-api: Project=technova, Environment=prod, ManagedBy=terraform, Aula=10, Name=technova-api
```
Todas vêm de `local.common_tags` + `Name` via `merge()` em cada recurso.

### Segurança do repositório
- `aula-10/.gitignore` ignora `.terraform/`, `*.tfstate*`, `tfplan`, `*.tfvars`, `.env`, `*.pem` e `technova-deploy.key`.
- `git ls-files` não lista state, `.env`, `.pem`, chave privada nem `.tfvars` (só `technova-deploy.pub`, chave **pública**). A chave privada ficou fora do repositório (apenas no secret `EC2_SSH_KEY`, removido ao final).
- Key pair automatizado: `aws_key_pair.deploy` lê a `.pub` versionada (sem passo manual de `InvalidKeyPair.NotFound`).

### Evidência do rollback
Tags no ECR: `sha-d88b6d4` (1.0.1) e `sha-64c147f` (1.1.0, `latest`). Seguindo o runbook, na EC2: login no ECR → pull de `sha-d88b6d4` → stop/rm → run. Saída real:
```
--- antes:  {"version":"1.1.0","commit":"64c147fd4ce7553fcbf5ee594f816b68fc9c03ee",...}
Login Succeeded
<ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com/technova-api:sha-d88b6d4
--- depois: {"status":"ok",...}
{"version":"1.0.1","commit":"sha-d88b6d4","deployedAt":"2026-10-24T01:29:56Z"}
<ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com/technova-api:sha-d88b6d4 Up 6 seconds (healthy)
```
`curl` externo em `http://<EC2_HOST>:3000/version` também respondeu `1.0.1`.

### Limpeza (regra de custos)
Após o destroy: sem EC2, repositório ECR, SG, key pair ou volumes (conferido por CLI) e bucket de state removido. Secrets AWS/EC2 apagados do repositório.
