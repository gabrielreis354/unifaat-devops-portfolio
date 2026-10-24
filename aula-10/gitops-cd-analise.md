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

## Evidências da execução
_Preenchidas após a execução no Learner Lab (links de PRs/runs, saídas de CLI, rollback)._
