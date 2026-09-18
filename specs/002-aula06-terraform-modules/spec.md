# SPEC: Aula 06 — Biblioteca de Módulos Terraform (TechNova)

> Fase: **Specify** (O QUÊ e PORQUÊ). Aguardando aprovação do Gabriel antes de ir para Plan.
> Base: `devops_20262/aula-06/TF.md` (fonte autoritativa — seguida estritamente),
> com referência de padrões de código em `aula-06/laboratorio-parte1.md` e
> `aula-06/laboratorio-parte2.md`.
> Convenções herdadas: `unifaat-devops-portfolio/aula-05-rds/` (tags, variáveis,
> RDS PostgreSQL) e `specs/001-aula05-rds-remote-state/` (formato de SPEC).

## 1. Objetivo

Construir, como código (Terraform), uma **biblioteca de 4 módulos reutilizáveis**
(`vpc`, `security-group`, `ec2`, `rds`) para a TechNova, e provisionar **dois
ambientes completos** (`dev` e `staging`) que consomem os mesmos módulos com
variáveis diferentes — eliminando a duplicação de código identificada no
trabalho em aula (7 pares de recursos idênticos entre dev/staging).
Entrega da disciplina: aluno **Gabriel Reis Cunha (RA 6325149)**.

## 2. Contexto / Motivação (Why)

- **DRY:** o `main.tf` atual da TechNova duplica ~90 linhas por ambiente (VPC,
  subnets, IGW, Security Groups, EC2) — 3 ambientes = ~270 linhas quase
  idênticas, com alto risco de drift entre elas (mudar uma regra de SG exige
  editar em N lugares).
- **Modularização:** extrair a lógica comum em módulos com `variables.tf` /
  `main.tf` / `outputs.tf` reduz um ambiente novo a um bloco `module {}` de
  ~20-30 linhas, com garantia de consistência estrutural entre ambientes.
- **`for_each` sobre `count`:** o módulo de VPC deve usar `for_each` (map de
  subnets nomeadas) em vez de `count` (lista por índice) — remover uma subnet
  do meio não deve forçar a recriação de outras, problema real do `count`.
- **Sem custo real:** o TF.md **não exige `terraform apply`** — só
  `terraform validate` e `terraform plan` limpos nos dois ambientes contam
  para a nota. Isso mantém a atividade em conformidade com a regra de custo
  (nenhum recurso AWS real precisa ser provisionado).

## 3. Escopo

### Dentro do escopo

Conforme a "Estrutura do Projeto" e os Requisitos 1-7 do `TF.md`, tudo dentro
de `unifaat-devops-portfolio/aula-06/`:

```
aula-06/
├── README.md
├── environments/
│   ├── dev/       (main.tf, variables.tf, outputs.tf, providers.tf, terraform.tfvars)
│   └── staging/   (main.tf, variables.tf, outputs.tf, providers.tf, terraform.tfvars)
└── modules/
    ├── vpc/              (main.tf, variables.tf, outputs.tf)
    ├── security-group/   (main.tf, variables.tf, outputs.tf)
    ├── ec2/              (main.tf, variables.tf, outputs.tf)
    └── rds/              (main.tf, variables.tf, outputs.tf)
```

- **`modules/vpc`** (Requisito 1): VPC com CIDR configurável; `for_each` sobre
  um mapa de subnets (`cidr`, `az`, `type`); suporte a públicas e privadas;
  Internet Gateway + Route Table para as públicas; outputs `vpc_id`,
  `public_subnet_ids`, `private_subnet_ids`.
- **`modules/security-group`** (Requisito 2): genérico (serve para API, RDS
  ou qualquer outro uso); `ingress_rules` como `list(object)`; egress padrão
  (all outbound); output `sg_id`.
- **`modules/ec2`** (Requisito 3): instância `t2.micro` com AMI, tipo, subnet
  e SGs configuráveis; `user_data` opcional; outputs `instance_id`,
  `public_ip`, `private_ip`.
- **`modules/rds`** (Requisito 4): DB Subnet Group com subnets privadas;
  RDS PostgreSQL `db.t3.micro`; configurações de lab (`skip_final_snapshot`
  etc.); outputs `db_endpoint`, `db_name`, `db_port`.
- **Composição** (Requisito 5): cada `environments/<env>/main.tf` chama os 4
  módulos encadeando outputs → inputs (VPC → SG → EC2/RDS).
- **Dois ambientes** (Requisito 6): `dev` (CIDR `10.0.0.0/16`) e `staging`
  (CIDR `10.1.0.0/16`), conforme a tabela de comparação do TF.md — mesmos
  módulos, variáveis (CIDRs, nomes, `db_name`) diferentes.
- **`README.md`** (Requisito 7): visão geral, diagrama de dependências, tabela
  de cada módulo (inputs/outputs/exemplo), como usar, pré-requisitos.
- **Boas práticas** (checklist do TF.md): `.gitignore` (sem `.tfstate`,
  `.terraform/`, `terraform.tfvars` reais com segredo, `*.pem`), tags
  (`Name`, `Environment`, `Project`, `ManagedBy`) em todo recurso, variáveis
  com `description`/`type`, outputs com `description`, `db_password`
  marcada `sensitive`.
- **Validação**: `terraform init` + `terraform validate` + `terraform plan`
  sem erros em `environments/dev` **e** `environments/staging`.
- **Entrega da disciplina**: `entregas/aula-06/6325149/entrega.md` — mesmo
  branch/PR #141 (que já tem o `trabalho-em-aula.md`) ou continuação dele.

### Fora do escopo (NÃO fazer)

- **`terraform apply`** — o TF.md diz explicitamente que não é obrigatório;
  só roda se eu quiser testar manualmente, e nesse caso `destroy` imediato
  (regra de custo). Não faz parte dos critérios de avaliação.
- **Backend remoto (S3/DynamoDB)** para o state do aula-06 — não é pedido
  pelo TF.md desta aula (diferente da aula-05); cada ambiente usa state
  local (não versionado, coberto pelo `.gitignore`).
- **Módulo do Terraform Registry** (`terraform-aws-modules/vpc/aws`) — usado
  só como demonstração no Lab Parte 2; não está nos requisitos nem nos
  critérios de avaliação do TF.md.
- **Versionamento via Git tags dos módulos** — conceito do Lab Parte 2, não
  exigido pelo TF.md.
- **`terraform_remote_state`** — conceito do Lab Parte 2, não exigido pelo
  TF.md (nenhum requisito ou critério de avaliação o menciona).
- **Ambiente de produção (`prod`)** — TF.md pede só dev + staging.
- **IAM Role/Instance Profile customizado** para o EC2/RDS — não é pedido
  pelo TF.md desta aula (`ec2`/`rds` não têm requisito de instance profile).
- Deploy real de aplicação no EC2 — fora do escopo dos módulos pedidos.

## 4. Requisitos funcionais

**Módulo `modules/vpc`**
- RF1: Variável `vpc_cidr` (string) — CIDR da VPC.
- RF2: Variáveis `project_name` (string) e `environment` (string) — usadas em
  tags/nomes.
- RF3: Variável `subnets` — `map(object({ cidr = string, az = string,
  type = string }))`.
- RF4: `resource "aws_vpc"` com `enable_dns_hostnames/support = true`.
- RF5: `resource "aws_subnet"` com `for_each = var.subnets`;
  `map_public_ip_on_launch` verdadeiro só quando `each.value.type == "public"`.
- RF6: `aws_internet_gateway` + `aws_route_table` (rota `0.0.0.0/0` → IGW) +
  `aws_route_table_association` **apenas** para as subnets cujo `type` é
  `"public"` (filtro via `local`).
- RF7: Outputs `vpc_id`, `public_subnet_ids` (lista, filtrada por `type`),
  `private_subnet_ids` (lista, filtrada por `type`).

**Módulo `modules/security-group`**
- RF8: Variáveis `name` (string), `vpc_id` (string), `ingress_rules`
  (`list(object({from_port,to_port,protocol,cidr_blocks,description}))`),
  `environment` (string), `project_name` (string).
- RF9: `resource "aws_security_group"` genérico + regras de ingress geradas
  dinamicamente a partir de `var.ingress_rules` (uma por item da lista).
- RF10: Regra de egress padrão (`0.0.0.0/0`, todo tráfego) sempre presente.
- RF11: Output `sg_id`.

**Módulo `modules/ec2`**
- RF12: Variáveis `instance_name`, `instance_type` (default `t2.micro`),
  `ami_id`, `subnet_id`, `security_group_ids` (list(string)), `key_name`.
- RF13: `resource "aws_instance"` usando essas variáveis; `user_data`
  opcional (default vazio/null).
- RF14: Outputs `instance_id`, `public_ip`, `private_ip`.

**Módulo `modules/rds`**
- RF15: Variáveis `db_name`, `db_username`, `db_password` (`sensitive =
  true`), `subnet_ids` (list(string)), `security_group_ids` (list(string)),
  `instance_class` (default `db.t3.micro`), `environment`, `project_name`.
- RF16: `resource "aws_db_subnet_group"` com `var.subnet_ids`.
- RF17: `resource "aws_db_instance"` PostgreSQL, `instance_class =
  var.instance_class`, `skip_final_snapshot = true`,
  `publicly_accessible = false`, `storage_encrypted = true`.
- RF18: Outputs `db_endpoint`, `db_name`, `db_port`.

**Composição e ambientes (`environments/dev`, `environments/staging`)**
- RF19: Cada ambiente é um root module independente: `providers.tf`
  (`required_providers` + `provider "aws"`), `variables.tf`, `main.tf`
  (chama os 4 módulos), `outputs.tf`, `terraform.tfvars`.
- RF20: `module.vpc.vpc_id` alimenta os `vpc_id` dos módulos
  `security-group`; `module.vpc.public_subnet_ids[0]` alimenta o `subnet_id`
  do `ec2`; `module.vpc.private_subnet_ids` alimenta `subnet_ids` do `rds`.
- RF21: `module.<sg>.sg_id` alimenta `security_group_ids` de `ec2` e `rds`
  (SGs distintos: um para API, um para RDS).
- RF22: `dev`: `vpc_cidr = "10.0.0.0/16"`, subnets públicas `10.0.1.0/24`/
  `10.0.2.0/24`, privadas `10.0.3.0/24`/`10.0.4.0/24`, `db_name =
  "technova_dev"`, naming `technova-dev-*`.
- RF23: `staging`: `vpc_cidr = "10.1.0.0/16"`, subnets públicas
  `10.1.1.0/24`/`10.1.2.0/24`, privadas `10.1.3.0/24`/`10.1.4.0/24`,
  `db_name = "technova_staging"`, naming `technova-staging-*`.
- RF24: `db_password` de cada ambiente definida em `terraform.tfvars`
  (gitignored), sem caracteres `@ / "` (restrição do TF.md).

**Documentação e entrega**
- RF25: `aula-06/README.md` com: visão geral, diagrama de dependências,
  tabela por módulo (inputs/outputs/exemplo de uso), como usar (criar novo
  ambiente), pré-requisitos.
- RF26: `entregas/aula-06/6325149/entrega.md` com link do portfólio +
  checklist do TF.md + evidência do `terraform plan` de um ambiente.

## 5. Requisitos não-funcionais / Restrições

- **Custo:** nenhum recurso AWS real precisa existir — só `validate`/`plan`.
  Se algum `apply` manual for feito para checar algo, `destroy` imediato
  (regra absoluta de custo) e isso não faz parte da entrega.
- **Identidade:** se algum comando AWS for necessário, sempre via role
  `voclabs` do Learner Lab, nunca root.
- **Stack:** Terraform `>= 1.0`; provider `hashicorp/aws ~> 5.0`; região
  `us-east-1`; PostgreSQL (mesma versão usada na aula-05: `"15"`).
- **Segurança:** `db_password` sempre `sensitive = true` e fora do
  versionamento (`terraform.tfvars` real no `.gitignore`; só
  `terraform.tfvars.example` versionado).
- **Convenções:** seguir o estilo de `aula-05-rds/` (tags, nomenclatura,
  `README.md` com reflexões reais) e os padrões de código dos labs (Lab
  Parte 2 para `vpc`/`ec2`/composição; Lab Parte 1 para `security-group`,
  que não muda entre as partes).
- **DRY/KISS:** módulos simples, sem generalizar além do que os requisitos
  pedem (ex.: não adicionar Multi-AZ, NAT Gateway ou opções não solicitadas).
- **Entrega:** Conventional Commits com corpo; branch dedicada; PR usa a
  branch já aberta `entregas/aula-06/6325149` (PR #141), adicionando o
  `entrega.md` do TF ao que já tem o `trabalho-em-aula.md`.

## 6. Critérios de aceitação (verificáveis)

- [ ] CA1: `terraform validate` retorna sucesso nos 4 módulos isoladamente
      (via `terraform init -backend=false` em cada `modules/*`, se aplicável)
      e em `environments/dev` e `environments/staging`.
- [ ] CA2: `terraform plan` em `environments/dev` não gera erro e mostra a
      criação de: 1 VPC, N subnets (`for_each`, chaves nomeadas visíveis no
      plan, ex. `module.vpc.aws_subnet.this["public-1"]`), IGW, route table
      + associations só nas públicas, 2 Security Groups (API e RDS), 1 EC2,
      1 DB Subnet Group, 1 RDS.
- [ ] CA3: Idêntico ao CA2 para `environments/staging`, com CIDRs e nomes
      próprios de staging (sem colisão de nomes/CIDRs com dev).
- [ ] CA4: Remover uma entrada do mapa `subnets` e rodar `plan` mostra
      **apenas aquela subnet** (e sua association, se pública) para destroy
      — nenhum outro recurso muda (prova o comportamento do `for_each`).
- [ ] CA5: `module.security_group` aceita uma lista de `ingress_rules` com 1
      ou mais regras e gera exatamente esse número de regras de ingress no
      plan, sem hardcode de porta específica dentro do módulo.
- [ ] CA6: Cada ambiente usa os módulos via composição — `grep` confirma
      `module.vpc.vpc_id`, `module.vpc.public_subnet_ids`,
      `module.vpc.private_subnet_ids` e `<sg>.sg_id` referenciados como
      inputs de outros módulos dentro do `main.tf` do ambiente.
- [ ] CA7: `db_password` aparece como `sensitive = true` no `variables.tf`
      do módulo `rds`, e o `terraform.tfvars` real de cada ambiente (com a
      senha) está fora do Git (`git check-ignore` confirma).
- [ ] CA8: Todos os recursos que suportam tag têm `Name`, `Environment`,
      `Project` (e `ManagedBy` onde aplicável).
- [ ] CA9: `aula-06/README.md` documenta os 4 módulos (tabela de inputs e
      outputs + exemplo de uso de cada um) e inclui o diagrama de
      dependências.
- [ ] CA10: `entregas/aula-06/6325149/entrega.md` existe na branch
      `entregas/aula-06/6325149` (PR #141), com o checklist do TF.md marcado
      e a evidência do `terraform plan` de um ambiente colada.
- [ ] CA11: `git status`/`git check-ignore` nos dois repos confirma que
      nenhum `*.tfstate`, `.terraform/`, `terraform.tfvars` real ou `*.pem`
      está versionado.

## 7. Riscos e questões em aberto

- **R1 — Módulo `rds` não tem exemplo nos labs:** será desenhado a partir do
  `aula-05-rds/rds.tf` já existente, adaptado às variáveis pedidas pelo
  Requisito 4. Risco baixo — mesma lógica já validada na aula-05.
- **R2 — `terraform validate` de módulos isolados:** módulos filhos (sem
  `provider` próprio) não rodam `validate` sozinhos da forma usual; a
  validação real acontece nos `environments/*` que os chamam. Vou confirmar
  isso no Plan e ajustar o CA1 se necessário.
- **R3 — Nomes de recursos entre dev e staging:** `aws_security_group.name`
  e `aws_db_instance.identifier` precisam ser únicos por ambiente/conta —
  usar `${project_name}-${environment}-...` em todo lugar evita colisão
  mesmo que, por algum motivo, um `apply` real venha a ser testado.
- **Q1 — RDS em `environments/staging` também usa subnets privadas de
  `module.vpc`, exatamente como no `dev`?** Assumindo que sim (mesma
  composição, só variáveis diferentes) — confirmar se não há objeção.
- **Q2 — O `entrega.md` do TF entra no mesmo PR #141** (branch
  `entregas/aula-06/6325149`, que já tem o `trabalho-em-aula.md`) ou em PR
  separado? Assumindo **mesmo PR** (permitido pelo TF.md: "pode ser
  adicionado no mesmo PR do TF ou em PR separado" — aqui é o inverso, mas a
  regra é simétrica).

## 8. Addendum — decisão do Gabriel (2026-09-17)

Apesar do TF.md não exigir `terraform apply`, o Gabriel pediu para rodar o
apply real do ambiente **dev** como smoke test ("para ter certeza que
funciona"), com `destroy` imediato após a evidência (regra de custo).
**Staging fica validado só por `plan`** — mesmos módulos que `dev`, TF.md
recomenda não aplicar os dois ao mesmo tempo (dobra o consumo do Learner
Lab). Nenhum dos módulos cria recursos IAM, então a orientação do professor
de usar `LabRole`/`LabInstanceProfile` (ver memória
`aws-academy-labrole-iam`) não se aplica a este TF especificamente, mas fica
registrada para os próximos.

## 9. Addendum — resultado do apply real (2026-09-17)

`terraform apply` em `environments/dev`: **19/19 recursos criados** (VPC,
4 subnets, IGW, route table + 2 associations, 2 SGs + 4 regras, EC2, RDS).
RDS `technova-dev-db` levou 5m33s para ficar `available`.

**Achado real:** a conta do Learner Lab rotacionou entre a aula-05
(`824991172345`) e hoje (`458963321324`) — a key pair `technova-key` da
aula-05 não existia na conta nova, causando `InvalidKeyPair.NotFound` na
criação do EC2. Corrigido com `aws ec2 import-key-pair --key-name
technova-key --public-key-material fileb://~/.ssh/technova-key.pub`
(reaproveita a mesma chave pública já gerada) e o `apply` completou o
recurso restante. Confirma a decisão D6 (key pair como pré-requisito
externo, não criado pelos módulos) — e vira nota prática no README/entrega:
**se a conta do lab rotacionar, reimportar a chave antes do apply.**

Pós-apply, verificado via `aws rds describe-db-instances` /
`describe-instances`: RDS `StorageEncrypted=true`, `MultiAZ=false`,
`PubliclyAccessible=false`; EC2 `running`. `terraform plan` logo em seguida
= **"No changes."** (state bate 100% com a infraestrutura real).

**Teardown:** `terraform destroy` → `Destroy complete! Resources: 19
destroyed.` Verificado pós-destroy: nenhum RDS/EC2/VPC com tag `technova`
restante na conta. `environments/staging` permanece validado só por `plan`
(mesmos módulos, TF.md desaconselha aplicar os dois ao mesmo tempo).
