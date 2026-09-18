# PLAN: Aula 06 — Biblioteca de Módulos Terraform (TechNova)

> Fase: **Plan** (o COMO técnico). SPEC aprovada 2026-09-17.
> Diretriz do Gabriel: seguir estritamente o `aula-06/TF.md`.

## 0. Resolução dos riscos/perguntas da SPEC

- **R2 (validate de módulo isolado):** confirmado — módulos filhos não têm
  `provider` próprio (herdam do root que os chama), então `terraform
  validate`/`plan` só rodam nos **root modules** (`environments/dev` e
  `environments/staging`), nunca dentro de `modules/*` diretamente. Isso
  valida os módulos **transitivamente**. Ajusta o CA1 da SPEC: validação =
  `init`+`validate`+`plan` nos dois `environments/*`. Mesma prática usada
  nos dois labs (nunca rodam `terraform` dentro de `modules/vpc/`).
- **Q1 (staging usa a mesma composição do dev):** confirmado pelo desenho —
  cada ambiente é 100% independente (próprio `module.vpc`, próprios SGs,
  próprio EC2/RDS), só variáveis mudam. Nenhuma dependência cross-ambiente.
- **Q2 (entrega.md no PR #141):** confirmado — adiciona commit à branch
  `entregas/aula-06/6325149` já aberta.
- **R1 (módulo rds sem exemplo nos labs):** resolvido abaixo (seção 2,
  módulo `rds`) — adaptado de `aula-05-rds/rds.tf`.

## 1. Arquitetura

```
environments/dev/main.tf                    environments/staging/main.tf
        │                                            │
        ├─ module.vpc (modules/vpc, for_each) ───────┼─ module.vpc
        │     outputs: vpc_id, public_subnet_ids[],  │
        │              private_subnet_ids[]           │
        │                                            │
        ├─ module.api_sg (modules/security-group)    ├─ module.api_sg
        │     in: vpc_id · out: sg_id                 │
        ├─ module.rds_sg (modules/security-group)    ├─ module.rds_sg
        │     in: vpc_id · out: sg_id                 │
        │                                            │
        ├─ data.aws_ami.amazon_linux                  ├─ data.aws_ami...
        │                                            │
        ├─ module.api_server (modules/ec2)            ├─ module.api_server
        │     in: subnet_id=vpc.public[0]             │
        │         security_group_ids=[api_sg.sg_id]   │
        │                                            │
        └─ module.database (modules/rds)              └─ module.database
              in: subnet_ids=vpc.private_subnet_ids[]
                  security_group_ids=[rds_sg.sg_id]

dev:     10.0.0.0/16  (pub 10.0.1-2.0/24, priv 10.0.3-4.0/24)  db=technova_dev
staging: 10.1.0.0/16  (pub 10.1.1-2.0/24, priv 10.1.3-4.0/24)  db=technova_staging
```

## 2. Módulos — arquivo por arquivo

### `modules/vpc/` — base: Lab Parte 2 (`vpc-dynamic`)

| Arquivo | Conteúdo |
|---|---|
| `variables.tf` | `vpc_cidr` (string) · `project_name` (string) · `environment` (string) · `subnets` `map(object({cidr=string, az=string, type=string}))` |
| `main.tf` | `aws_vpc.main` (dns hostnames/support) · `aws_internet_gateway.main` · `aws_subnet.this` com `for_each = var.subnets`, `map_public_ip_on_launch = each.value.type == "public"` · `aws_route_table.public` (rota `0.0.0.0/0`→IGW) · `locals.public_subnets` (filtra `type=="public"`) · `aws_route_table_association.public` com `for_each = local.public_subnets` |
| `outputs.tf` | `vpc_id` · `public_subnet_ids` = `[for k,s in aws_subnet.this : s.id if var.subnets[k].type=="public"]` · `private_subnet_ids` (idem, `"private"`) |

Tags em todo recurso: `Name = "${project_name}-${environment}-..."`,
`Environment = var.environment`, `Project = var.project_name`,
`ManagedBy = "terraform"` (subnets recebem também `Type = each.value.type`).

### `modules/security-group/` — base: Lab Parte 1

| Arquivo | Conteúdo |
|---|---|
| `variables.tf` | `name` · `description` (default) · `vpc_id` · `ingress_rules` `list(object({from_port,to_port,protocol,cidr_blocks,description}))` (default `[]`) · `egress_rules` (default = 1 regra all-outbound) · `environment` · `project_name` |
| `main.tf` | `aws_security_group.this` · `aws_security_group_rule.ingress` com `count = length(var.ingress_rules)` · `aws_security_group_rule.egress` com `count = length(var.egress_rules)` |
| `outputs.tf` | `sg_id`, `sg_name` |

Genérico por construção: quem chama decide as regras (API abre 80+22 de
`0.0.0.0/0`; RDS abre 5432 só do `vpc_cidr` — igual ao padrão já usado em
`aula-05-rds/rds.tf`, sem inventar SG-por-SG que não foi pedido).

### `modules/ec2/` — base: Lab Parte 2

| Arquivo | Conteúdo |
|---|---|
| `variables.tf` | `instance_name` · `instance_type` (default `t2.micro`) · `ami_id` · `subnet_id` · `security_group_ids` (list(string)) · `key_name` · `user_data` (default `""`) · `environment` · `project_name` |
| `main.tf` | `aws_instance.this` (`user_data = var.user_data != "" ? var.user_data : null`) |
| `outputs.tf` | `instance_id`, `public_ip`, `private_ip` |

AMI resolvida **fora** do módulo (no `main.tf` de cada ambiente, via
`data "aws_ami" "amazon_linux"`, igual ao Lab Parte 2 §3.4) e passada como
`ami_id` — o módulo fica agnóstico de qual imagem usar.

### `modules/rds/` — **sem exemplo nos labs**, adaptado de `aula-05-rds/rds.tf`

| Arquivo | Conteúdo |
|---|---|
| `variables.tf` | `db_name` · `db_username` · `db_password` (`sensitive = true`, sem default) · `subnet_ids` (list(string)) · `security_group_ids` (list(string)) · `instance_class` (default `db.t3.micro`) · `environment` · `project_name` |
| `main.tf` | `aws_db_subnet_group.main` (`subnet_ids = var.subnet_ids`) · `aws_db_instance.main` (`engine="postgres"`, `engine_version="15"` — mesma versão validada na aula-05 — `allocated_storage=20`, `storage_type="gp2"`, `instance_class=var.instance_class`, `db_subnet_group_name`, `vpc_security_group_ids=var.security_group_ids`, `publicly_accessible=false`, `multi_az=false`, `storage_encrypted=true`, `skip_final_snapshot=true`) |
| `outputs.tf` | `db_endpoint`, `db_name`, `db_port` |

Simplificação deliberada em relação à aula-05 (KISS/YAGNI — o TF.md desta
aula não pede backup nem manutenção): sem `backup_retention_period`/
`backup_window`/`maintenance_window` explícitos (usa defaults do provider);
sem `performance_insights_enabled` (já é `false` por padrão). O essencial
pedido pelo Requisito 4 (`skip_final_snapshot`, subnet group, instância
PostgreSQL parametrizável) está coberto.

## 3. Ambientes — `environments/dev/` e `environments/staging/`

Cada um é um **root module independente** (state local próprio, sem
backend remoto — fora de escopo por SPEC):

| Arquivo | Conteúdo |
|---|---|
| `providers.tf` | `terraform { required_version >= 1.0; required_providers { aws ~> 5.0 } }` + `provider "aws" { region = var.aws_region }` |
| `variables.tf` | `aws_region` (default `us-east-1`), `project_name` (default `technova`), `environment`, `key_name` (default `technova-key`), `db_username`, `db_password` (sensitive, sem default) |
| `main.tf` | `module.vpc` (`source = "../../modules/vpc"`, `subnets = {...}` do ambiente) → `module.api_sg` / `module.rds_sg` (`vpc_id = module.vpc.vpc_id`) → `data.aws_ami.amazon_linux` → `module.api_server` (`subnet_id = module.vpc.public_subnet_ids[0]`, `security_group_ids = [module.api_sg.sg_id]`) → `module.database` (`subnet_ids = module.vpc.private_subnet_ids`, `security_group_ids = [module.rds_sg.sg_id]`) |
| `outputs.tf` | `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `api_sg_id`, `rds_sg_id`, `ec2_public_ip`, `db_endpoint` |
| `terraform.tfvars` | valores reais do ambiente (**gitignored** — contém `db_password**) |
| `terraform.tfvars.example` | versionável, `db_password = "TrocarSenha123"` (alfanumérico, sem `@ / "`) |
| `.gitignore` | `.terraform/`, `*.tfstate*`, `terraform.tfvars`, `.terraform.lock.hcl` |

**dev** (`environment = "dev"`):
```hcl
subnets = {
  "public-1"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public"  }
  "public-2"  = { cidr = "10.0.2.0/24", az = "us-east-1b", type = "public"  }
  "private-1" = { cidr = "10.0.3.0/24", az = "us-east-1a", type = "private" }
  "private-2" = { cidr = "10.0.4.0/24", az = "us-east-1b", type = "private" }
}
```
`vpc_cidr = "10.0.0.0/16"`, `db_name = "technova_dev"`.

**staging** (`environment = "staging"`): idêntico, trocando `10.0.` → `10.1.`
em tudo, `db_name = "technova_staging"`.

Naming de todos os recursos: `${project_name}-${environment}-*` — garante
que `dev` e `staging` nunca colidem em nome, mesmo que alguém rode `apply`
dos dois ao mesmo tempo (R3 da SPEC).

## 4. Fluxo de verificação (sem apply)

```bash
cd aula-06/environments/dev
terraform init
terraform validate
terraform plan            # CA2: ~19 recursos (1 vpc+1 igw+4 subnets+1 rt+2 assoc
                           #      +2 sg+2 ingress+2 egress+1 ec2+1 db_subnet_group+1 rds)

cd ../staging
terraform init
terraform validate
terraform plan            # CA3: mesma contagem, CIDRs/nomes de staging

# CA4 — comportamento do for_each: comentar/remover "private-2" do main.tf
# de um ambiente e rodar `terraform plan` de novo -> só aquela subnet some
# do plano (destroy), nenhum outro recurso é tocado. Reverter depois do teste.
```

Nenhum destes comandos cria recursos reais — só leitura de schema/sintaxe e
comparação local. Não há sessão do Learner Lab nem credenciais AWS
necessárias para `validate`; `plan` sem credenciais/backend específico
também funciona para recursos que não dependem de *data sources* remotos —
mas `data "aws_ami"` **precisa** de credenciais válidas (é uma consulta real
à API da AWS). Portanto o `plan` completo exige `source aws-creds.sh`
carregado (mesmo sem criar nada).

## 5. Documentação (`aula-06/README.md`)

Estrutura (Requisito 7 do TF.md):
1. Visão geral da biblioteca
2. Diagrama de dependências (ASCII, igual à seção 1 deste plano)
3. Tabela por módulo: nome, descrição, inputs, outputs, exemplo de uso
   (formato do TF.md, seção "Exemplo de documentação de módulo")
4. Como usar — criar um ambiente novo (`environments/prod` como exercício
   mental, sem implementar)
5. Pré-requisitos — AWS CLI, Terraform ≥1.0, chave `~/.ssh/technova-key`
   (reaproveitada da aula-05), `aws-creds.sh`

## 6. Decisões e trade-offs

| # | Decisão | Alternativa | Por quê |
|---|---|---|---|
| D1 | `for_each` com map de objetos no módulo `vpc` (Lab Parte 2) | `count` com listas (Lab Parte 1) | TF.md Requisito 1 pede `for_each` explicitamente |
| D2 | `environments/dev` e `environments/staging` como **roots separados** | 1 root + `-var-file` (padrão dos labs) | É a estrutura de diretórios exigida pelo TF.md |
| D3 | `security-group` com `aws_security_group_rule` + `count` | `dynamic "ingress"` inline | Replica o padrão já usado no Lab (mais simples de auditar no `plan`, uma regra = um recurso) |
| D4 | `modules/rds` novo, baseado no `aula-05-rds/rds.tf` | Copiar de algum lab | Nenhum lab cobre RDS; a base validada na aula-05 é a fonte mais confiável |
| D5 | Sem backend remoto para o state do aula-06 | Reusar backend da aula-05 | TF.md não pede; fora do escopo (SPEC) |
| D6 | `key_name` como variável simples (sem `aws_key_pair` no módulo) | Criar key pair no módulo `ec2` | TF.md trata key pair como pré-requisito externo (dica 5 do README), não como entregável dos módulos |
| D7 | SG do RDS por `cidr_blocks = [vpc_cidr]` | SG-por-SG | Mesma decisão tomada na aula-05 (seguir o TF/lab literalmente, sem bônus não pedido) |
| D8 | `engine_version = "15"` no módulo `rds` | outra versão | Mesma validada na aula-05 (15.13-15.19 disponíveis, plan fica limpo) |

## 7. Riscos remanescentes

- **`data "aws_ami"` exige credenciais válidas para o `plan` funcionar** —
  documentar isso no README/entrega.md; se a sessão do Lab expirar entre a
  aula-05 e agora, só rodar `source aws-creds.sh` de novo (sem custo).
- **`terraform validate` não pega tudo** — erros de referência a outputs
  inexistentes só aparecem no `plan` (que já está no fluxo de verificação).
