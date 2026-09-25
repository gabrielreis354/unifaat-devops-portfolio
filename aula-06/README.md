# Aula 06 — Módulos Terraform | Gabriel Reis Cunha (RA: 6325149)

Biblioteca de 4 módulos Terraform reutilizáveis para a TechNova
(`vpc`, `security-group`, `ec2`, `rds`) e dois ambientes completos
(`dev` e `staging`) que consomem os mesmos módulos com variáveis diferentes —
eliminando a duplicação de ~90 linhas por ambiente identificada no
[trabalho em aula](https://github.com/AleTavares/devops_20262/pull/141).

## Visão Geral

```
aula-06/
├── environments/
│   ├── dev/       ← root module: VPC 10.0.0.0/16
│   └── staging/   ← root module: VPC 10.1.0.0/16 (mesmos módulos, outras variáveis)
└── modules/
    ├── vpc/              ← VPC + subnets dinâmicas (for_each) + IGW + route table
    ├── security-group/   ← Security Group genérico (regras como lista de objetos)
    ├── ec2/               ← instância EC2 parametrizável
    └── rds/               ← RDS PostgreSQL parametrizável
```

Cada ambiente em `environments/` é um **root module independente** — tem seu
próprio state, providers e variáveis — e chama os 4 módulos com valores
próprios. Não existe backend remoto aqui (fora do escopo desta aula; ver
`../aula-05/backend/` para o padrão S3+DynamoDB usado na aula-05).

## Arquitetura — Diagrama de Dependências

```
environments/<env>/main.tf
        │
        ├─ module.vpc  (modules/vpc, for_each sobre var.subnets)
        │     outputs: vpc_id, public_subnet_ids[], private_subnet_ids[]
        │
        ├─ module.api_sg  (modules/security-group)         vpc_id ◄──┐
        │     ingress: 80 (HTTP), 22 (SSH) de 0.0.0.0/0                │
        │     output: sg_id                                            │
        ├─ module.rds_sg  (modules/security-group)          vpc_id ◄──┘
        │     ingress: 5432 (PostgreSQL) do vpc_cidr
        │     output: sg_id
        │
        ├─ data.aws_ami.amazon_linux  (resolvida no ambiente, não no módulo)
        │
        ├─ module.api_server  (modules/ec2)
        │     in: subnet_id = vpc.public_subnet_ids[0]
        │         security_group_ids = [api_sg.sg_id]
        │
        └─ module.database  (modules/rds)
              in: subnet_ids = vpc.private_subnet_ids
                  security_group_ids = [rds_sg.sg_id]
```

O `vpc` é sempre o primeiro módulo: todos os outros dependem do `vpc_id` ou
dos `subnet_ids` que ele expõe. Os Security Groups dependem só do `vpc_id`;
o EC2 depende de 2 módulos (`vpc` + `security-group`); o RDS também depende
de 2 (`vpc` + `security-group`).

## Módulos

### `modules/vpc`

**Descrição:** Cria VPC completa com subnets dinâmicas (`for_each` sobre um
mapa), Internet Gateway e route table pública (associada só às subnets
`type = "public"`).

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|:---:|-----------|
| `vpc_cidr` | string | Sim | CIDR block da VPC |
| `project_name` | string | Sim | Nome do projeto (tags/nomes) |
| `environment` | string | Sim | Ambiente (dev, staging, prod) |
| `subnets` | `map(object({cidr, az, type}))` | Sim | Mapa de subnets (chave = nome) |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| `vpc_id` | ID da VPC criada |
| `public_subnet_ids` | Lista de IDs das subnets `type = "public"` |
| `private_subnet_ids` | Lista de IDs das subnets `type = "private"` |

**Exemplo de uso:**
```hcl
module "vpc" {
  source       = "../../modules/vpc"
  vpc_cidr     = "10.0.0.0/16"
  project_name = "technova"
  environment  = "dev"
  subnets = {
    "public-1"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public"  }
    "private-1" = { cidr = "10.0.3.0/24", az = "us-east-1a", type = "private" }
  }
}
```

### `modules/security-group`

**Descrição:** Security Group genérico — serve para API, RDS, bastion ou
qualquer outra finalidade. Regras de entrada vêm como lista de objetos; a
saída padrão (all outbound) já vem com um default, mas pode ser sobrescrita.

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|:---:|-----------|
| `name` | string | Sim | Nome do Security Group |
| `description` | string | Não (default) | Descrição |
| `vpc_id` | string | Sim | ID da VPC |
| `ingress_rules` | `list(object({from_port,to_port,protocol,cidr_blocks,description}))` | Não (default `[]`) | Regras de entrada |
| `egress_rules` | mesmo formato | Não (default = all outbound) | Regras de saída |
| `environment` | string | Sim | Ambiente |
| `project_name` | string | Sim | Nome do projeto |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| `sg_id` | ID do Security Group |
| `sg_name` | Nome do Security Group |

**Exemplo de uso:**
```hcl
module "api_sg" {
  source       = "../../modules/security-group"
  name         = "technova-dev-api-sg"
  vpc_id       = module.vpc.vpc_id
  environment  = "dev"
  project_name = "technova"
  ingress_rules = [
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "HTTP" },
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "SSH" }
  ]
}
```

### `modules/ec2`

**Descrição:** Instância EC2 reutilizável — AMI, tipo, subnet, Security
Groups e `user_data` configuráveis. A resolução da AMI (`data "aws_ami"`)
fica **fora** do módulo, no `main.tf` de cada ambiente — o módulo só recebe
o `ami_id` já resolvido.

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|:---:|-----------|
| `instance_name` | string | Sim | Nome da instância |
| `instance_type` | string | Não (default `t2.micro`) | Tipo da instância |
| `ami_id` | string | Sim | AMI ID |
| `subnet_id` | string | Sim | Subnet onde a instância nasce |
| `security_group_ids` | list(string) | Sim | Security Groups |
| `key_name` | string | Sim | Key pair para SSH (pré-requisito externo) |
| `user_data` | string | Não (default `""`) | Script de inicialização |
| `environment` | string | Sim | Ambiente |
| `project_name` | string | Sim | Nome do projeto |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| `instance_id` | ID da instância |
| `public_ip` | IP público |
| `private_ip` | IP privado |

**Exemplo de uso:**
```hcl
module "api_server" {
  source              = "../../modules/ec2"
  instance_name       = "technova-dev-api"
  ami_id              = data.aws_ami.amazon_linux.id
  subnet_id           = module.vpc.public_subnet_ids[0]
  security_group_ids  = [module.api_sg.sg_id]
  key_name            = "technova-key"
  environment         = "dev"
  project_name        = "technova"
}
```

### `modules/rds`

**Descrição:** RDS PostgreSQL reutilizável — DB Subnet Group + instância
com configurações sensatas para desenvolvimento (`skip_final_snapshot`,
`storage_encrypted`, `publicly_accessible = false`). Não existe exemplo
pronto nos labs desta aula; foi adaptado do `aula-05/rds.tf` (já
validado com `terraform apply` real na aula-05).

**Inputs:**
| Nome | Tipo | Obrigatório | Descrição |
|------|------|:---:|-----------|
| `db_name` | string | Sim | Nome do banco |
| `db_username` | string | Sim | Usuário master |
| `db_password` | string (`sensitive`) | Sim | Senha master |
| `subnet_ids` | list(string) | Sim | Subnets privadas para o DB Subnet Group |
| `security_group_ids` | list(string) | Sim | Security Groups do RDS |
| `instance_class` | string | Não (default `db.t3.micro`) | Classe da instância |
| `environment` | string | Sim | Ambiente |
| `project_name` | string | Sim | Nome do projeto |

**Outputs:**
| Nome | Descrição |
|------|-----------|
| `db_endpoint` | Endpoint de conexão (host:porta) |
| `db_name` | Nome do banco |
| `db_port` | Porta (5432) |

**Exemplo de uso:**
```hcl
module "database" {
  source              = "../../modules/rds"
  db_name             = "technova_dev"
  db_username         = "technova_admin"
  db_password         = var.db_password
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.rds_sg.sg_id]
  environment         = "dev"
  project_name        = "technova"
}
```

## Como Usar — Criar um Novo Ambiente

Para adicionar, por exemplo, um ambiente `prod`, basta copiar a estrutura de
`environments/dev/` para `environments/prod/` e trocar os valores em
`variables.tf` (CIDR `10.2.0.0/16`, subnets `10.2.x.0/24`, `environment =
"prod"`). Nenhum módulo precisa ser tocado — é exatamente o ganho que a
modularização traz (visto no trabalho em aula: ~20-30 linhas por ambiente
novo, em vez de ~90).

## Pré-requisitos

- Terraform `>= 1.0`
- AWS CLI configurado
- Acesso ao **AWS Academy Learner Lab** (credenciais via `source
  aws-creds.sh` na raiz do repositório — reaproveita o script da aula-05)
- Key pair `technova-key` já existente na conta (`ssh-keygen` — ver
  `aula-05/README.md`); os módulos **não** criam a chave, só a referenciam.
  > **Nota prática:** a conta do AWS Academy Learner Lab pode rotacionar
  > entre sessões/semanas. Se der `InvalidKeyPair.NotFound` num `apply`,
  > reimporte a chave pública já gerada na conta atual:
  > `aws ec2 import-key-pair --key-name technova-key --public-key-material fileb://~/.ssh/technova-key.pub`

## Validação (sem `apply`)

O TF.md desta aula não exige `terraform apply` — só `validate` e `plan`
limpos contam para a nota:

```bash
source ../aws-creds.sh   # necessario: data "aws_ami" consulta a AWS de verdade

cd environments/dev
terraform init
terraform validate   # Success! The configuration is valid.
terraform plan        # Plan: 19 to add, 0 to change, 0 to destroy.

cd ../staging
terraform init
terraform validate
terraform plan        # mesma contagem, CIDRs/nomes de staging
```

**Prova do `for_each` seletivo:** removendo uma subnet do mapa `subnets` em
`variables.tf` e rodando `plan` de novo, **só aquela subnet** (e sua
`route_table_association`, se pública) aparece na diferença — as demais
mantêm as mesmas chaves nomeadas, sem reindexação. Testado durante o
desenvolvimento: 19 → 18 recursos ao remover `"private-2"`, sem nenhum outro
recurso afetado.

**Smoke test com `apply` real:** apesar de não ser exigido, o ambiente `dev`
foi aplicado de verdade uma vez para confirmar que os módulos funcionam de
ponta a ponta — 19 recursos criados, RDS validado como criptografado/não
público/não Multi-AZ, `terraform plan` deu "No changes" logo em seguida, e
tudo foi destruído na mesma sessão. Detalhes em
`../specs/002-aula06-terraform-modules/spec.md` (seção "Addendum —
resultado do apply real").
