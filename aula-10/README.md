# Aula 10 — Terraform Automatizado (GitOps) e Pipeline CD

Infra e deploy da **TechNova** viram código revisável: PR → plan comentado → merge → apply; push na `main` → lint → test → build → push (ECR) → deploy (Recreate via SSH) → health check.

## Mapa de arquivos
| Item | Onde |
|---|---|
| Terraform (provider+backend S3, EC2, SG, key pair, ECR) | `aula-10/terraform/` |
| Bootstrap do bucket de state (via CLI) | `aula-10/terraform/bootstrap.sh` |
| App + Dockerfile multi-stage | `aula-10/technova-api/` |
| Workflows | `.github/workflows/` na **raiz** (o GitHub só executa a raiz): `terraform-plan.yml`, `terraform-apply.yml`, `terraform-destroy.yml`, `cd.yml`, `aws-check.yml` |
| Análise | `aula-10/gitops-cd-analise.md` |
| Runbook de rollback | `aula-10/docs/runbook-rollback.md` |
| Screenshots | `aula-10/screenshots/` (`plan-pr-comment`, `apply-success`, `cd-pipeline-green`, `health-check-pass`) |

> Learner Lab: sem OIDC/IAM próprio — autenticação por credenciais de sessão como secrets; EC2 usa `LabInstanceProfile`.

## Como reproduzir
1. Iniciar o Learner Lab e exportar as credenciais (`aws sts get-caller-identity` deve mostrar `voclabs`, nunca root).
2. `aula-10/terraform/bootstrap.sh` — cria o bucket `technova-tfstate-<ACCOUNT_ID>`.
3. Gerar a chave de deploy: `ssh-keygen -t ed25519 -N "" -f technova-deploy.key` e copiar a `.pub` para `aula-10/terraform/technova-deploy.pub` (a privada **nunca** vai ao Git).
4. Secrets do repositório: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_ACCOUNT_ID`, `EC2_USERNAME` (`ubuntu`), `EC2_SSH_KEY` (chave privada), `EC2_HOST` (output `ec2_public_ip` do primeiro apply). Validar com o workflow **AWS Check**.
5. PR com mudança em `aula-10/terraform/**` → plan comentado → merge → apply.
6. Push em `aula-10/technova-api/**` na `main` → CD completo.
7. **Ao terminar:** workflow **Terraform Destroy** (digitar `destroy`), apagar o bucket de state, End Lab e remover os secrets AWS/EC2.

Teste local da app: `cd aula-10/technova-api && npm ci && npm run lint && npm test`.
