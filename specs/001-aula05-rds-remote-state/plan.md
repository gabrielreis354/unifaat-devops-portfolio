# PLAN: Aula 05 — RDS PostgreSQL + Remote State (S3 + DynamoDB)

> Fase: **Plan** (o COMO técnico). SPEC aprovada 2026-09-10.
> Diretriz do Gabriel: **implementar exatamente como o `TF.md` e os `laboratorio-parte1/2.md` pedem.**
> Limite de custo AWS Academy: US$ 50 — mesmo assim, teardown imediato após evidências.

## 0. Verificações no ambiente real (creds voclabs válidas)

| Item | Resultado | Efeito |
|------|-----------|--------|
| Identidade | `assumed-role/voclabs/...Gabriel_Reis_Cunha` (não-root) | OK operar |
| PostgreSQL 15 em us-east-1 | 15.13…15.19 (provider aws ~>5.0 aceita `"15"` por prefixo, sem drift) | usar `engine_version = "15"` (lab 5.1) |
| `db.t3.micro` + pg15 + `gp2` | suportado | mantém |
| AZs us-east-1 | a…f | `names[0]`=1a, `names[1]`=1b |

## 1. Arquitetura

```
                       Internet
                          │
                 ┌────────┴────────┐
                 │ Internet Gateway│
                 └────────┬────────┘
 VPC technova 10.0.0.0/16 │
 ┌─────────────────────────────────────────────────────────┐
 │ Subnet PÚBLICA 10.0.1.0/24 (1a)                          │
 │    ┌───────────────┐  SG ec2: in 22 + 3000 (0.0.0.0/0)   │
 │    │ EC2 t2.micro  │  out all                            │
 │    │ + postgresql15│                                     │
 │    └───────┬───────┘                                     │
 │  ─ ─ ─ ─ ─ ┼ 5432 (dentro do CIDR 10.0.0.0/16) ─ ─ ─ ─ ─ │
 │ Subnet PRIVADA 10.0.2.0/24 (1a) ┐ DB Subnet Group        │
 │ Subnet PRIVADA 10.0.4.0/24 (1b) ┘                        │
 │    ┌──────────────────────────┐  SG rds: in 5432 do CIDR │
 │    │ RDS PostgreSQL 15         │  da VPC; out all         │
 │    │ db.t3.micro 20GB gp2      │  (sem rota p/ internet)  │
 │    │ encrypted, not public     │                         │
 │    └──────────────────────────┘                          │
 └─────────────────────────────────────────────────────────┘
 State: aula-05 ──backend s3──▶ s3://technova-terraform-state-<rand>/aula-05/terraform.tfstate
                                    lock ▶ dynamodb technova-terraform-locks (LockID)
```

CIDRs das subnets idênticos ao lab: pública `10.0.1.0/24`, privada-1 `10.0.2.0/24`,
privada-2 `10.0.4.0/24`.

## 2. Estrutura de arquivos

### `unifaat-devops-portfolio/aula-05/backend/`  (state infra — apply primeiro; base: lab parte 2)

| Arquivo | Conteúdo |
|---------|----------|
| `main.tf` | `terraform { required_version >= 1.0; required_providers = aws ~>5.0, random ~>3.0 }` + `provider "aws"` região us-east-1 |
| `variables.tf` | `project_name` (default `technova`) |
| `s3.tf` | `random_id.bucket_suffix` (8 bytes) · `aws_s3_bucket.terraform_state` name `${project_name}-terraform-state-${random_id.hex}` · `aws_s3_bucket_versioning` Enabled · `aws_s3_bucket_server_side_encryption_configuration` com `sse_algorithm = "aws:kms"` (chave gerenciada `aws/s3`, sem custo) · `aws_s3_bucket_public_access_block` (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets` = true) |
| `dynamodb.tf` | `aws_dynamodb_table.terraform_locks` name `${project_name}-terraform-locks`, `billing_mode = "PAY_PER_REQUEST"`, `hash_key = "LockID"`, `attribute { name = "LockID"; type = "S" }` |
| `outputs.tf` | `s3_bucket_name` (= id), `s3_bucket_arn`, `dynamodb_table_name` |
| `.gitignore` | `.terraform/`, `*.tfstate`, `*.tfstate.*`, `.terraform.lock.hcl`, `aws-creds.sh` |

Tags (lab parte 2 pede em todos os recursos): `Project = "TechNova"`,
`Purpose = "Terraform Remote State"`. Aplicadas via `tags = local.common_tags` em cada
recurso (o lab não usa `default_tags` aqui) — ou `default_tags` no provider, equivalente
e mais DRY. **Decisão:** `default_tags` no provider (KISS/DRY), resultado idêntico.

### `unifaat-devops-portfolio/aula-05/`  (infra principal; base: lab parte 1)

| Arquivo | Conteúdo (idêntico ao lab parte 1, seções 1.1–8.1) |
|---------|----------|
| `providers.tf` | `terraform { required_version >= 1.0; required_providers = aws ~>5.0 }` + **bloco `backend "s3"`** (bucket/tabela preenchidos após apply do backend; `key = "aula-05/terraform.tfstate"`, `region = "us-east-1"`, `encrypt = true`, `dynamodb_table = ...`) + `provider "aws" { region = var.aws_region }` |
| `variables.tf` | `aws_region` (us-east-1), `project_name` (technova), `vpc_cidr` (10.0.0.0/16), `db_username` (technova_admin), `db_password` (`sensitive = true`, sem default), `db_name` (technova) — exatamente lab 1.2 |
| `terraform.tfvars` | `aws_region = "us-east-1"` + `db_password = "<definido na hora>"` — **gitignored** |
| `terraform.tfvars.example` | versionável, `db_password = "TROQUE-ME"` |
| `vpc.tf` | `data.aws_availability_zones.available` · `aws_vpc.main` (cidr var, DNS on) · `aws_internet_gateway.main` · `aws_subnet.public` (10.0.1.0/24, `names[0]`, `map_public_ip_on_launch = true`) · `aws_subnet.private_1` (10.0.2.0/24, `names[0]`) · `aws_subnet.private_2` (10.0.4.0/24, `names[1]`) · `aws_route_table.public` (0.0.0.0/0 → igw) · `aws_route_table_association.public` — lab 2.1 |
| `rds.tf` | `aws_db_subnet_group.main` ([private_1, private_2]) · `aws_security_group.rds` (ingress 5432 `cidr_blocks = [var.vpc_cidr]`; egress all) · `aws_db_instance.main` (identifier `${project_name}-db`, `engine = "postgres"`, `engine_version = "15"`, `instance_class = "db.t3.micro"`, `allocated_storage = 20`, `storage_type = "gp2"`, `db_name`/`username`/`password`/`port = 5432` via var, `db_subnet_group_name`, `vpc_security_group_ids = [sg.rds]`, `publicly_accessible = false`, `multi_az = false`, `backup_retention_period = 7`, `backup_window = "03:00-04:00"`, `maintenance_window = "sun:04:00-sun:05:00"`, `storage_encrypted = true`, `skip_final_snapshot = true`, `performance_insights_enabled = false`) — lab 3.1/4.1/5.1 |
| `ec2.tf` | `data.aws_ami.amazon_linux` (`owners=["amazon"]`, filtro `al2023-ami-*-x86_64`, `hvm`, `most_recent`) · `aws_key_pair.main` (`key_name = "${project_name}-key"`, `public_key = file("~/.ssh/technova-key.pub")`) · `aws_security_group.ec2` (ingress 22 + 3000 de 0.0.0.0/0; egress all) · `aws_instance.api` (ami data, `t2.micro`, `key_name`, `subnet_id = public`, `vpc_security_group_ids = [sg.ec2]`, `user_data` = `yum update -y` + `yum install -y postgresql15`) — lab 6.1 |
| `outputs.tf` | `vpc_id`, `rds_endpoint`, `rds_address`, `rds_port`, `rds_database_name`, `ec2_public_ip`, `connection_string` (`psql -h ${address} -U ${db_username} -d ${db_name} -p ${port}`) — lab 8.1 |
| `.gitignore` | `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `terraform.tfvars`, `.terraform.lock.hcl`, `aws-creds.sh`, `*.pem`, `*.key` — lab 1.4 |
| `README.md` | template do TF.md: design da estrutura, menor privilégio (2 exemplos + "e se usasse FullAccess"), diagrama User→SG→Recursos + fluxo EC2→RDS, comandos, reflexão manual vs Terraform, **+ reflexão Spec-Driven vs manual** (lab parte 2 §6) |

Tags no `aula-05`: o lab usa `tags = { Name=..., Project=var.project_name, Aula="05" }`
por recurso. **Decisão:** replicar esse padrão do lab por recurso (não `default_tags`),
para ficar igual ao roteiro. `Name` específico por recurso + `Project` + `Aula = "05"`.

### `devops_20262/` (fork da disciplina)

`entregas/aula-05/6325149/entrega.md` — modelo do TF.md + 4 evidências.

## 3. Stack / versões

- Terraform `>= 1.0` · `hashicorp/aws ~> 5.0` · `hashicorp/random ~> 3.0` (só backend)
- Região `us-east-1` · PostgreSQL `15` · AMI Amazon Linux 2023
- **Sem** provider `tls`/`local`: a chave SSH é criada fora do Terraform com `ssh-keygen`
  (lab 6.1) e referenciada por `file("~/.ssh/technova-key.pub")`.

## 4. Pré-requisito de chave SSH (uma vez, lab 6.1)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/technova-key -N ""
chmod 400 ~/.ssh/technova-key
```

## 5. Fluxo de execução (ordem obrigatória — lab parte 2 §3-4-7)

```bash
# Learner Lab verde; em unifaat-devops-portfolio/ ; source aws-creds.sh

# 1) BACKEND
cd aula-05/backend
terraform init && terraform validate && terraform plan
terraform apply                       # ~6 recursos: random_id, bucket, versioning, sse, bpa, dynamodb
BUCKET=$(terraform output -raw s3_bucket_name)
TABLE=$(terraform output -raw dynamodb_table_name)

# 2) INFRA PRINCIPAL — escrever BUCKET/TABLE no backend "s3" do aula-05/providers.tf
cd ../aula-05
printf 'aws_region  = "us-east-1"\ndb_password = "%s"\n' "<SENHA>" > terraform.tfvars
terraform init                        # cria state direto no S3 (ou -migrate-state se houver local)
terraform validate && terraform plan
terraform apply                       # VPC + RDS (5-10 min) + EC2

# 3) EVIDÊNCIAS
terraform output
aws s3 ls s3://$BUCKET/aula-05/                                          # EV1
ssh -i ~/.ssh/technova-key ec2-user@$(terraform output -raw ec2_public_ip)
  psql -h <endpoint> -U technova_admin -d technova -c "SELECT version();" # EV2
  # CREATE TABLE orders (...) + INSERT x3 + SELECT * FROM orders;         # EV3
terraform plan   # "No changes."                                         # EV4

# 4) TEARDOWN (MESMA SESSÃO, logo após evidências) — lab parte 2 §7
cd ../aula-05 && terraform destroy
BUCKET=...   # esvaziar versões + delete markers
aws s3api list-object-versions --bucket $BUCKET --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text \
  | while read k v; do aws s3api delete-object --bucket $BUCKET --key "$k" --version-id "$v"; done
aws s3api list-object-versions --bucket $BUCKET --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text \
  | while read k v; do aws s3api delete-object --bucket $BUCKET --key "$k" --version-id "$v"; done
cd ../aula-05/backend && terraform destroy

# 5) VERIFICAÇÃO PÓS-TEARDOWN
terraform state list                                   # vazio (2x)
aws rds describe-db-instances --query "DBInstances[?DBInstanceIdentifier=='technova-db']"
aws s3 ls | grep technova || echo "bucket removido"
aws dynamodb list-tables | grep technova || echo "tabela removida"
```

Bootstrap do `backend "s3"`: o bloco `backend` não aceita variáveis; os valores de
bucket/tabela entram **hardcoded** no `providers.tf` do `aula-05` após o apply do
backend (lab parte 2 §4.3 mostra exatamente esse `providers.tf` final).

## 6. Decisões (todas alinhadas ao TF.md / lab)

| # | Decisão | Fonte |
|---|---------|-------|
| 1 | SG do RDS: 5432 `cidr_blocks = [var.vpc_cidr]` | lab parte 1 §4.1 |
| 2 | Criptografia S3: SSE-KMS via chave **gerenciada `aws/s3`** (`sse_algorithm = "aws:kms"`) | lab parte 2 §1.2 ("KMS") + TF.md ("server-side"); chave gerenciada = sem custo nem janela de deleção |
| 3 | `engine_version = "15"` | lab parte 1 §5.1 |
| 4 | `backup_retention_period = 7` + janelas | lab parte 1 §5.1 |
| 5 | Chave SSH por `ssh-keygen` + `file("~/.ssh/technova-key.pub")` | lab parte 1 §6.1 |
| 6 | Duas pastas `aula-05/backend/` + `aula-05/` | lab parte 2 (estrutura) + TF.md fluxo recomendado |
| 7 | Sem NAT Gateway / IAM Instance Profile | não pedidos pelo TF.md; NAT tem custo/hora |
| 8 | `backend "s3"` hardcoded pós-bootstrap | limitação do Terraform (sem var em `backend`); lab §4.3 |

## 7. Riscos remanescentes

- **R1 voclabs**: se `aws_s3_bucket_public_access_block` ou `aws_db_instance` for negado,
  capturar o erro; BPA reprovado seria bloqueio real → escalar ao professor.
- **R2 sessão ~4 h do Learner Lab**: renovar `aws-creds.sh` e retomar do state remoto;
  nunca deixar RDS/EC2 ativos entre sessões (US$ 50 é teto, não meta).
- **R3 destroy do bucket**: coberto pelo esvaziamento de versões + delete markers.
- **R4 `psql` logo após o apply**: aguardar fim do cloud-init (~1-2 min) ou instalar à mão.
- **R5 chave SSH ausente**: rodar o `ssh-keygen` da §4 antes do `terraform apply` do `aula-05`.

## 8. Addendum — execução real (2026-09-10/11)

- **R1 se confirmou:** o SCP do AWS Academy Learner Lab (`p-6v4y751d`) nega
  explicitamente `s3:GetBucketObjectLockConfiguration`. O recurso `aws_s3_bucket`
  do provider `hashicorp/aws` chama essa API em toda leitura/criação/import —
  testado nas versões `5.100.0` e `5.42.0`, ambas falham. Todas as outras chamadas
  S3 necessárias (create-bucket, put/get-versioning, put/get-encryption,
  put/get-public-access-block) funcionam normalmente.
- **Decisão do Gabriel (Opção A):** o bucket do state é criado por
  `aula-05/backend/bootstrap.sh` (AWS CLI puro — idempotente, com verificação e
  impressão do bloco `backend "s3"` pronto). A tabela DynamoDB continua 100% em
  Terraform (`dynamodb.tf`). `s3.tf` e o provider `hashicorp/random` foram removidos
  do módulo. `aula-05/backend/teardown.sh` esvazia (versões + delete markers) e
  apaga o bucket no fim.
- **Resultado:** bucket `technova-terraform-state-54600b3e83155696` — versionado,
  SSE-KMS, Block Public Access 4/4 — e state do `aula-05` migrado com sucesso
  (`aws s3 ls` mostrou `aula-05/terraform.tfstate`).
- **WSL/perf:** o provider `aws` (~700 MB) demorava a iniciar em `/mnt/c`
  ("timeout while waiting for plugin to start"). Contornado com
  `TF_DATA_DIR` apontando para o filesystem Linux (`~/.tfdata/<modulo>`).
- **`terraform apply` do `aula-05`:** 13 recursos criados; RDS levou 12m22s.
  Todas as 4 evidências (CA5-CA8) + a negativa (CA7) capturadas com sucesso —
  ver `specs/001-aula05-rds-remote-state/evidencias/`.
- **Teardown:** `terraform destroy` do `aula-05` (13 destruídos, RDS ~1m52s) →
  bucket esvaziado e removido → `terraform destroy` do `aula-05/backend`
  (DynamoDB destruído). Verificado CA11: nenhum recurso `technova-*` restante
  (RDS, S3, DynamoDB, EC2, VPC).
