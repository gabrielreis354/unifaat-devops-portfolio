# TASKS: Aula 05 — RDS PostgreSQL + Remote State

> SPEC + Plan aprovados. Diretriz: **exatamente como o TF.md / laboratorio-parte1-2.**
> `[x]` ao concluir + evidência. 🖥️ = código · ☁️ = Learner Lab ativo · 👤 = Gabriel

---

## Bloco A — Código `aula-05/backend/`  🖥️  (base: lab parte 2)

- [x] A1. `.gitignore` (`.terraform/`, `*.tfstate`, `*.tfstate.*`, `.terraform.lock.hcl`, `aws-creds.sh`).
- [x] A2. `main.tf`: `terraform` block (`>=1.0`, aws `~>5.0`, random `~>3.0`) + `provider "aws"`
      us-east-1 + `default_tags { Project="TechNova", Purpose="Terraform Remote State" }`.
- [x] A3. `variables.tf`: `project_name` default `technova`.
- [x] A4. `s3.tf`: `random_id.bucket_suffix` (8B) · `aws_s3_bucket.terraform_state`
      (`${var.project_name}-terraform-state-${random_id.bucket_suffix.hex}`) ·
      `aws_s3_bucket_versioning` (`status = "Enabled"`) ·
      `aws_s3_bucket_server_side_encryption_configuration` (`sse_algorithm = "aws:kms"`) ·
      `aws_s3_bucket_public_access_block` (4× `true`).
- [x] A5. `dynamodb.tf`: `aws_dynamodb_table.terraform_locks`
      (`billing_mode="PAY_PER_REQUEST"`, `hash_key="LockID"`, attribute `LockID`/`S`).
- [x] A6. `outputs.tf`: `s3_bucket_name`, `s3_bucket_arn`, `dynamodb_table_name`.
- [x] A7. `terraform fmt` + `terraform init -backend=false` + `terraform validate`.
      **Verif.:** "Success! The configuration is valid."

## Bloco B — Código `aula-05/`  🖥️  (base: lab parte 1, seções 1.1–8.1)

- [x] B1. `.gitignore` (lab 1.4: `.terraform/`, `*.tfstate`, `*.tfstate.backup`,
      `terraform.tfvars`, `.terraform.lock.hcl`, `aws-creds.sh`, `*.pem`, `*.key`).
- [x] B2. `providers.tf`: `terraform` block (`>=1.0`, aws `~>5.0`) + `backend "s3"`
      (valores de bucket/tabela como placeholder comentado — preenchidos em C3;
      `key = "aula-05/terraform.tfstate"`, `region = "us-east-1"`, `encrypt = true`) +
      `provider "aws" { region = var.aws_region }`.
- [x] B3. `variables.tf`: `aws_region`, `project_name`, `vpc_cidr`, `db_username`,
      `db_password` (`sensitive = true`, sem default), `db_name` — exatamente lab 1.2.
- [x] B4. `terraform.tfvars.example` (versionável) com `aws_region` + `db_password = "TROQUE-ME"`.
- [x] B5. `vpc.tf` (lab 2.1): data AZs · VPC · IGW · subnet pública 10.0.1.0/24 (`names[0]`,
      map_public_ip) · privada_1 10.0.2.0/24 (`names[0]`) · privada_2 10.0.4.0/24 (`names[1]`) ·
      route table pública (0.0.0.0/0→IGW) · association. Tags `Name`/`Project`/`Type`.
- [x] B6. `rds.tf` (lab 3.1+4.1+5.1): `aws_db_subnet_group.main` [priv1,priv2] ·
      `aws_security_group.rds` (ingress 5432 `cidr_blocks=[var.vpc_cidr]`; egress all) ·
      `aws_db_instance.main` (postgres, `engine_version="15"`, db.t3.micro, 20, gp2,
      db_name/username/password/port via var, subnet group, sg rds, publicly_accessible=false,
      multi_az=false, backup_retention_period=7, backup_window "03:00-04:00",
      maintenance_window "sun:04:00-sun:05:00", storage_encrypted=true,
      skip_final_snapshot=true, performance_insights_enabled=false). Tags `Name`/`Project`/`Aula="05"`.
- [x] B7. `ec2.tf` (lab 6.1): data AMI al2023 x86_64 · `aws_key_pair.main`
      (`public_key = file("~/.ssh/technova-key.pub")`) · `aws_security_group.ec2`
      (ingress 22 + 3000 de 0.0.0.0/0; egress all) · `aws_instance.api` (t2.micro,
      key_name, subnet pública, sg ec2, user_data `yum update -y` + `yum install -y postgresql15`).
- [x] B8. `outputs.tf` (lab 8.1): `vpc_id`, `rds_endpoint`, `rds_address`, `rds_port`,
      `rds_database_name`, `ec2_public_ip`, `connection_string`.
- [x] B9. `terraform fmt` + `terraform init -backend=false` + `terraform validate`.
      **Verif.:** válido.

## Bloco C — Backend na AWS  ☁️

- [x] C1. 👤 Learner Lab **Start Lab** verde + `aws-creds.sh` atualizado.
      🖥️ `source aws-creds.sh` → confere ARN `voclabs` (não-root).
- [x] C2. 👤 (uma vez) `ssh-keygen -t rsa -b 4096 -f ~/.ssh/technova-key -N "" && chmod 400 ~/.ssh/technova-key`.
- [x] C3. `cd aula-05/backend` → `terraform init` → `validate` → `plan` (~6 add) → `apply`.
      **Verif.:** `aws s3api get-bucket-versioning` (Enabled),
      `aws s3api get-public-access-block` (4× true),
      `aws s3api get-bucket-encryption` (aws:kms),
      `aws dynamodb describe-table --table-name technova-terraform-locks` (LockID/S). → **CA2**
- [x] C4. 🖥️ `terraform output -raw s3_bucket_name` / `dynamodb_table_name` →
      preencher `backend "s3"` no `aula-05/providers.tf`.

## Bloco D — Infra principal + state remoto  ☁️

- [x] D1. 👤 senha do banco → 🖥️ `printf 'aws_region="us-east-1"\ndb_password="..."\n' > aula-05/terraform.tfvars`.
- [x] D2. `cd aula-05` → `source ../aws-creds.sh` → `terraform init`
      (state criado direto no S3; se houver local, `-migrate-state` + `yes`).
      **Verif.:** `aws s3 ls s3://<bucket>/aula-05/` lista `terraform.tfstate`. → **CA3**
- [x] D3. `terraform validate && terraform plan`.
      **Verif.:** VPC(1)+subnets(3)+IGW(1)+RT(1)+assoc(1)+db_subnet_group(1)+SG(2)+RDS(1)+
      key_pair(1)+EC2(1); 0 erro.
- [x] D4. `terraform apply` (RDS 5–10 min).
      **Verif.:** `terraform output` → `rds_endpoint`, `ec2_public_ip`. → **CA4**

## Bloco E — Evidências  ☁️  (saída bruta → `entrega.md` + `specs/.../evidencias/`)

- [x] E1. **EV1:** `aws s3 ls s3://<bucket>/aula-05/`.
- [x] E2. **EV2:** `ssh -i ~/.ssh/technova-key ec2-user@<ip>` →
      `psql -h <endpoint> -U technova_admin -d technova -c "SELECT version();"`. → **CA5**
- [x] E3. **EV3:** no psql — `CREATE TABLE orders (id SERIAL PK, customer_name, product,
      quantity, total, created_at DEFAULT now())` + 3 `INSERT` (lab 7.1) + `SELECT * FROM orders;`. → **CA6**
- [x] E4. **EV-neg:** `psql` da máquina local p/ o endpoint → timeout. → **CA7**
- [x] E5. **EV4:** `terraform plan` → "No changes." → **CA8**

## Bloco F — Teardown  ☁️  (MESMA SESSÃO, logo após E) — regra de custo

- [x] F1. `cd aula-05 && terraform destroy` → `yes`.
- [x] F2. Esvaziar bucket: `Versions` + `DeleteMarkers` (script Plan §5).
- [x] F3. `cd ../aula-05/backend && terraform destroy` → `yes`.
- [x] F4. **Verif.:** `terraform state list` vazio (2×); `aws rds describe-db-instances`
      sem `technova-db`; `aws s3 ls | grep technova` vazio; `aws dynamodb list-tables`
      sem `technova-terraform-locks`. → **CA11**
- [x] F5. 🖥️ remover `aula-05/terraform.tfvars`. (chave `~/.ssh/technova-key*` fica p/ reuso)

## Bloco G — Documentação e entrega  🖥️ / 👤

- [x] G1. `aula-05/README.md` — template do TF.md (design, menor privilégio c/ 2
      exemplos + "e se FullAccess", diagrama, comandos, reflexão manual×Terraform) +
      reflexão **Spec-Driven × manual** (lab parte 2 §6). → **CA12**
- [ ] G2. `entregas/aula-05/6325149/entrega.md` (fork, branch `entregas/aula-05/6325149`):
      modelo TF.md + checklist marcado + EV1/EV2/EV3. → **CA10**
- [x] G3. 🖥️ `git status` sem segredos nos 2 repos (`*.tfstate`, `terraform.tfvars`,
      `*.pem`, `aws-creds.sh`). → **CA9**
- [ ] G4. Portfólio: branch `feature/aula-05-remote-state` → commit (Conventional
      Commits + corpo) → merge `--no-ff` na `main` → push. Inclui `specs/`.
- [ ] G5. 👤 Fork: commit da `entrega.md` → push → PR
      `[Aula 05] RA: 6325149 - GABRIEL REIS CUNHA` p/ `AleTavares/devops_20262:main`.
      **Confirmar com o Gabriel antes de push/PR.**

---

## Rastreabilidade Tasks → CA

| CA | Task |
|----|------|
| CA1 validate | A7, B9 |
| CA2 backend S3+DynamoDB | C3 |
| CA3 state no S3 | D2 |
| CA4 apply infra | D4 |
| CA5 psql SELECT version() | E2 |
| CA6 orders persistente | E3 |
| CA7 RDS não exposto | E4 |
| CA8 plan "No changes" | E5 |
| CA9 sem segredo no Git | G3 |
| CA10 entrega.md | G2 |
| CA11 teardown vazio | F4 |
| CA12 README | G1 |
