# TASKS: Aula 06 — Biblioteca de Módulos Terraform (TechNova)

> SPEC + Plan aprovados. Nenhuma task depende do Learner Lab exceto o `plan`
> final (que consulta `data "aws_ami"`, uma leitura real na AWS — sem custo).
> `[x]` ao concluir + evidência. 🖥️ = código · ☁️ = precisa de credenciais AWS válidas (só leitura)

---

## Bloco A — `modules/vpc/` 🖥️

- [x] A1. `variables.tf`: `vpc_cidr`, `project_name`, `environment`, `subnets`
      (`map(object({cidr,az,type}))`).
- [x] A2. `main.tf`: `aws_vpc.main` · `aws_internet_gateway.main` ·
      `aws_subnet.this` (`for_each`, `map_public_ip_on_launch` condicional) ·
      `aws_route_table.public` · `locals.public_subnets` ·
      `aws_route_table_association.public` (`for_each` só nas públicas).
- [x] A3. `outputs.tf`: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`.

## Bloco B — `modules/security-group/` 🖥️

- [x] B1. `variables.tf`: `name`, `description` (default), `vpc_id`,
      `ingress_rules` (list(object), default `[]`), `egress_rules` (default
      = 1 regra all-outbound), `environment`, `project_name`.
- [x] B2. `main.tf`: `aws_security_group.this` + `aws_security_group_rule.ingress`
      (`count`) + `aws_security_group_rule.egress` (`count`).
- [x] B3. `outputs.tf`: `sg_id`, `sg_name`.

## Bloco C — `modules/ec2/` 🖥️

- [x] C1. `variables.tf`: `instance_name`, `instance_type` (default
      `t2.micro`), `ami_id`, `subnet_id`, `security_group_ids`, `key_name`,
      `user_data` (default `""`), `environment`, `project_name`.
- [x] C2. `main.tf`: `aws_instance.this`.
- [x] C3. `outputs.tf`: `instance_id`, `public_ip`, `private_ip`.

## Bloco D — `modules/rds/` 🖥️ (baseado em `aula-05/rds.tf`)

- [x] D1. `variables.tf`: `db_name`, `db_username`, `db_password`
      (`sensitive=true`, sem default), `subnet_ids`, `security_group_ids`,
      `instance_class` (default `db.t3.micro`), `environment`,
      `project_name`.
- [x] D2. `main.tf`: `aws_db_subnet_group.main` + `aws_db_instance.main`
      (postgres 15, `skip_final_snapshot=true`, `publicly_accessible=false`,
      `storage_encrypted=true`).
- [x] D3. `outputs.tf`: `db_endpoint`, `db_name`, `db_port`.

## Bloco E — `environments/dev/` 🖥️

- [x] E1. `.gitignore` (`.terraform/`, `*.tfstate*`, `terraform.tfvars`,
      `.terraform.lock.hcl`).
- [x] E2. `providers.tf` (aws `~>5.0`, `region = var.aws_region`).
- [x] E3. `variables.tf` (`aws_region`, `project_name`, `environment`,
      `key_name`, `db_username`, `db_password` sensitive).
- [x] E4. `main.tf`: `module.vpc` (subnets dev) → `module.api_sg` (80+22) /
      `module.rds_sg` (5432 do vpc_cidr) → `data.aws_ami.amazon_linux` →
      `module.api_server` → `module.database`.
- [x] E5. `outputs.tf`: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`,
      `api_sg_id`, `rds_sg_id`, `ec2_public_ip`, `db_endpoint`.
- [x] E6. `terraform.tfvars.example` (versionável) + `terraform.tfvars`
      real (gitignored, senha alfanumérica sem `@ / "`).
- [x] E7. `terraform fmt` + `terraform init` + `terraform validate`.
      **Verif.:** "Success! The configuration is valid."

## Bloco F — `environments/staging/` 🖥️ (espelha o Bloco E)

- [x] F1-F7. Idêntico ao Bloco E, trocando `10.0.` → `10.1.`,
      `environment = "staging"`, `db_name = "technova_staging"`, naming
      `technova-staging-*`. `terraform validate` também deve passar.

## Bloco G — Verificação (`plan`, precisa de credenciais AWS válidas) ☁️

- [x] G1. 👤 Confirmar `aws-creds.sh` válido (`source` + `sts get-caller-identity`
      — reaproveita o da aula-05, sem custo, só leitura).
- [x] G2. `cd environments/dev && terraform plan`.
      **Verif.:** sem erro; ~19 recursos a criar; chaves nomeadas do
      `for_each` visíveis (`module.vpc.aws_subnet.this["public-1"]` etc). → **CA2**
- [x] G3. `cd environments/staging && terraform plan`.
      **Verif.:** idem, CIDRs/nomes de staging, sem colisão com dev. → **CA3**
- [x] G4. Teste do `for_each` (CA4): comentar `"private-2"` no `main.tf` de
      um ambiente, `terraform plan` → só essa subnet aparece para destroy;
      reverter o comentário depois. → **CA4**
- [x] G5. Conferir no `plan` de G2 que o número de regras de ingress geradas
      bate com o tamanho de `ingress_rules` passado (2 para API, 1 para
      RDS). → **CA5**
- [x] G6. `grep` nos `main.tf` dos dois ambientes confirmando a composição
      (`module.vpc.vpc_id`, `.public_subnet_ids`, `.private_subnet_ids`,
      `.sg_id` usados como input de outro módulo). → **CA6**
- [x] G7. `git check-ignore` confirma `terraform.tfvars` real ignorado nos
      dois ambientes; `db_password` com `sensitive=true` no módulo `rds`. → **CA7, CA11**
- [x] G8. Conferir tags (`Name`, `Environment`, `Project`, `ManagedBy`) em
      todos os recursos dos 4 módulos. → **CA8**

## Bloco H — Documentação e entrega 🖥️ / 👤

- [x] H1. `aula-06/README.md`: visão geral, diagrama, tabela de cada módulo
      (inputs/outputs/exemplo), como usar, pré-requisitos. → **CA9**
- [x] H2. `entregas/aula-06/6325149/entrega.md`: modelo do TF.md + checklist
      marcado + evidência do `terraform plan` de um ambiente (dev). → **CA10**
- [x] H3. 🖥️ `git status`/`git check-ignore` final nos dois repos — sem
      `*.tfstate`, `.terraform/`, `terraform.tfvars` real, `*.pem`. → **CA11**
- [ ] H4. Commit + push no portfólio (`feature/aula-06-modules` → merge
      `--no-ff` na `main`, igual ao fluxo da aula-05).
- [ ] H5. 👤 Commit da `entrega.md` na branch `entregas/aula-06/6325149`
      (já existe, PR #141 aberto) → push. **Confirmar com o Gabriel antes
      do push.**

---

## Rastreabilidade Tasks → Critérios de Aceitação

| CA | Task |
|----|------|
| CA1 validate | E7, F7 |
| CA2 plan dev | G2 |
| CA3 plan staging | G3 |
| CA4 for_each seletivo | G4 |
| CA5 ingress_rules genérico | G5 |
| CA6 composição rastreável | G6 |
| CA7 segredo protegido | G7 |
| CA8 tags | G8 |
| CA9 README | H1 |
| CA10 entrega.md | H2 |
| CA11 nada sensível versionado | G7, H3 |
