# SPEC: Aula 05 — RDS PostgreSQL + Remote State (S3 + DynamoDB)

> Fase: **Specify** (O QUÊ e PORQUÊ). Aguardando aprovação do Gabriel antes de ir para Plan.
> Base: `devops_20262/aula-05/TF.md`, `aula-05/laboratorio-parte1.md`, `aula-05/laboratorio-parte2.md`.
> Convenções herdadas: `unifaat-devops-portfolio/aula-04/` (default_tags, var `owner` = RA, keypair gerado via Terraform).

## 1. Objetivo

Provisionar, como código (Terraform), a camada de dados da TechNova — um PostgreSQL
gerenciado (Amazon RDS) em subnets privadas, acessível apenas por um EC2 na subnet
pública da mesma VPC — e proteger o Terraform state em backend remoto (bucket S3
com versionamento/criptografia + trava de concorrência no DynamoDB).
Entrega da disciplina: aluno **Gabriel Reis Cunha (RA 6325149)**.

## 2. Contexto / Motivação (Why)

- **Persistência de dados:** nas aulas anteriores a infra era stateless (EC2 + VPC).
  RDS separa o ciclo de vida dos dados do ciclo de vida do servidor — reiniciar,
  recriar ou trocar o EC2 não pode destruir os dados.
- **State compartilhável e seguro:** `terraform.tfstate` local não serve para equipe
  (não versiona, sem trava, contém segredos em claro). Backend S3 + lock DynamoDB é o
  padrão para trabalho colaborativo e é critério de maior peso do TF (25%).
- **Menor privilégio de rede:** o banco nunca deve ser alcançável da internet;
  só o EC2 da aplicação, dentro da VPC, fala na porta 5432.
- **Custo:** todo o exercício roda no **AWS Academy Learner Lab**. Recursos pagos
  (RDS, EC2, S3, DynamoDB) só existem o tempo de capturar evidências e são destruídos
  imediatamente depois (regra absoluta de custos AWS).

## 3. Escopo

### Dentro do escopo

- **Módulo raiz `aula-05-backend/`** (infra de state):
  - Bucket S3 com nome globalmente único (sufixo aleatório), versionamento,
    criptografia server-side e Block Public Access (4 flags = true).
  - Tabela DynamoDB com partition key `LockID` (String), billing PAY_PER_REQUEST.
  - Outputs: nome do bucket, ARN do bucket, nome da tabela.
- **Módulo raiz `aula-05-rds/`** (infra principal):
  - VPC `10.0.0.0/16` com 1 subnet pública + 2 subnets privadas em **AZs diferentes**,
    Internet Gateway, route table pública associada.
  - DB Subnet Group com as 2 subnets privadas.
  - RDS PostgreSQL 15, `db.t3.micro`, `allocated_storage = 20`, `gp2`,
    `multi_az = false`, `publicly_accessible = false`, `storage_encrypted = true`,
    `skip_final_snapshot = true`. Credenciais via variáveis (`sensitive = true`).
  - EC2 `t2.micro` na subnet pública, com cliente PostgreSQL instalado via `user_data`.
  - Key pair SSH criado com `ssh-keygen` e referenciado por
    `file("~/.ssh/technova-key.pub")` (lab parte 1 §6.1).
  - Security Groups: EC2 (22 e 3000 da internet) e RDS (5432 **apenas do CIDR da
    VPC** — `cidr_blocks = [var.vpc_cidr]`, conforme lab parte 1 §4.1).
  - `backend "s3"` configurado no Terraform apontando para o bucket/tabela do módulo
    de backend, com `encrypt = true`; state migrado do local para o S3.
  - Outputs: endpoint/porta/nome do RDS, IP público do EC2, connection string sem senha.
- **Qualidade de código:** arquivos `.tf` separados por responsabilidade; tags em todos
  os recursos (via `default_tags`: Project, ManagedBy, Owner=RA, Aula=05, Environment);
  `.gitignore` cobrindo `.terraform/`, `*.tfstate*`, `*.tfvars`, `*.pem`, `aws-creds.sh`.
- **Evidências** (capturadas com a infra no ar, coladas na `entrega.md`):
  1. State no S3 (`aws s3 ls s3://<bucket>/aula-05/`).
  2. Conexão EC2 → RDS (`psql ... -c "SELECT version();"`).
  3. Dados persistentes (tabela `orders` criada + `SELECT * FROM orders;`).
  4. `terraform plan` limpo ("No changes") após o apply.
- **Teardown:** `terraform destroy` no `aula-05-rds`, esvaziamento do bucket
  (incluindo versões) e `terraform destroy` no `aula-05-backend` — **na mesma sessão**,
  logo após as evidências.
- **Entrega da disciplina:** `entregas/aula-05/6325149/entrega.md` no fork de
  `devops_20262`, branch `entregas/aula-05/6325149`, PR para `main`.
- **README.md** em `aula-05/` do portfólio: design da rede, menor privilégio,
  reflexão remote state (por que S3+DynamoDB), reflexão Spec-Driven vs manual.

### Fora do escopo (NÃO fazer)
- SG do RDS por Security Group de origem (bônus #1) — usar CIDR da VPC como o lab.

- IAM Role / Instance Profile custom para o EC2 (o role `voclabs` do Learner Lab não
  cria IAM; é bônus opcional do TF). Fica registrado como possível extensão.
- Terraform workspaces dev/prod (bônus).
- NAT Gateway / rota de saída para as subnets privadas (RDS não precisa de internet).
- Multi-AZ, réplicas de leitura, Performance Insights, snapshot final.
- Deploy real da API Node.js no EC2 (basta o cliente `psql` para provar a conexão).
- Pipeline CI/CD, monitoramento, alarmes.
- Versionar qualquer `.tf` no repositório `devops_20262` (só a `entrega.md` vai no PR).

## 4. Requisitos funcionais

**Backend (`aula-05-backend/`)**
- RF1: Criar bucket S3 com sufixo aleatório no nome (`random_id` ou equivalente).
- RF2: Habilitar versionamento no bucket.
- RF3: Habilitar criptografia server-side no bucket.
- RF4: Aplicar `aws_s3_bucket_public_access_block` com as 4 flags = `true`.
- RF5: Criar tabela DynamoDB `hash_key = "LockID"`, atributo `LockID` tipo `S`,
  `billing_mode = "PAY_PER_REQUEST"`.
- RF6: Exportar via output o nome do bucket, o ARN do bucket e o nome da tabela.

**Rede (`aula-05-rds/`)**
- RF7: VPC `10.0.0.0/16` com DNS hostnames/support habilitados.
- RF8: 1 subnet pública (`map_public_ip_on_launch = true`) com rota `0.0.0.0/0` → IGW.
- RF9: 2 subnets privadas em AZs distintas (`names[0]` e `names[1]` de
  `aws_availability_zones`), sem rota para a internet.
- RF10: DB Subnet Group contendo exatamente as 2 subnets privadas.

**Banco (`aula-05-rds/`)**
- RF11: RDS PostgreSQL 15, `db.t3.micro`, storage 20 GB `gp2`, `multi_az = false`,
  `publicly_accessible = false`, `storage_encrypted = true`, `skip_final_snapshot = true`.
- RF12: `db_name`, `username` e `password` vindos de variáveis; `password` com
  `sensitive = true` e fora do versionamento (`terraform.tfvars`).
- RF13: Security Group do RDS permite ingress TCP 5432 **apenas** do CIDR da VPC
  (`cidr_blocks = [var.vpc_cidr]`).

**Servidor (`aula-05-rds/`)**
- RF14: EC2 `t2.micro` na subnet pública, AMI Amazon Linux via data source
  `most_recent`.
- RF15: Key pair criado com `ssh-keygen -t rsa -b 4096 -f ~/.ssh/technova-key` e
  registrado via `aws_key_pair` com `public_key = file("~/.ssh/technova-key.pub")`.
- RF16: Security Group do EC2 permite ingress 22 e 3000 de `0.0.0.0/0` e egress total.
- RF17: `user_data` instala o cliente PostgreSQL 15.

**State remoto (`aula-05-rds/`)**
- RF18: Bloco `backend "s3"` com `bucket`, `key = "aula-05/terraform.tfstate"`,
  `region = "us-east-1"`, `encrypt = true`, `dynamodb_table = <tabela>`.
- RF19: `terraform init -migrate-state` move o state local para o S3 sem perda de
  recursos gerenciados.

**Outputs e organização**
- RF20: Outputs no `aula-05-rds`: `rds_endpoint`, `rds_address`, `rds_port`,
  `rds_database_name`, `ec2_public_ip`, `connection_string` (sem senha), `vpc_id`.
- RF21: Código em múltiplos arquivos `.tf` por responsabilidade
  (`providers.tf`, `variables.tf`, `vpc.tf`, `rds.tf`, `ec2.tf`, `outputs.tf`).
- RF22: Todos os recursos que suportam tag recebem `Project`, `ManagedBy`, `Owner`
  (RA 6325149), `Aula = "05"` e `Environment`.

**Entrega**
- RF23: `entregas/aula-05/6325149/entrega.md` preenchido com o modelo do TF.md +
  as 4 evidências.
- RF24: `aula-05/README.md` no portfólio com design da rede, reflexão sobre menor
  privilégio, reflexão sobre remote state e reflexão Spec-Driven vs manual.

## 5. Requisitos não-funcionais / Restrições

- **Custo — regra absoluta:** somente free-tier / crédito do Learner Lab. Após capturar
  as evidências, destruir tudo na mesma sessão (RDS, EC2, VPC, bucket esvaziado,
  DynamoDB). Nada de recurso ativo ao fim da sessão.
- **Identidade:** operar sempre com o role IAM `voclabs` do Learner Lab. Se a
  identidade autenticada for `root`, não executar nada — alertar.
- **Segurança:**
  - Banco inacessível pela internet (subnet privada + `publicly_accessible = false`
    + SG restrito por SG de origem).
  - Segredos (`password`, `aws-creds.sh`, `terraform.tfvars`, `*.pem`, `*.tfstate`)
    nunca versionados.
  - `sensitive = true` nas variáveis e outputs sensíveis.
- **Stack fixa:** Terraform `>= 1.0`; provider `hashicorp/aws ~> 5.0` (+ `hashicorp/random`
  só no módulo de backend); região `us-east-1`; PostgreSQL `15` (`engine_version = "15"`).
- **Convenções:** seguir o estilo já usado em `aula-04/` do portfólio
  (`default_tags` no provider, variáveis `aws_region`/`project_name`/`environment`/
  `owner`, keypair gerado no Terraform).
- **Tempo de provisionamento:** criação/destruição do RDS leva 5–10 min; aceitável.
- **Entrega:** Conventional Commits com corpo; branch dedicada; nunca commit direto na
  `main` de repo compartilhado; PR para o `devops_20262` só com a `entrega.md`.

## 6. Critérios de aceitação (verificáveis)

- [ ] CA1: `terraform validate` passa nos dois módulos (`aula-05-backend`, `aula-05-rds`).
- [ ] CA2: `terraform apply` do `aula-05-backend` cria bucket S3 (versionado,
      criptografado, Block Public Access 4/4) e tabela DynamoDB com `LockID` (S).
      Verificável por `aws s3api get-bucket-versioning`,
      `aws s3api get-public-access-block` e `aws dynamodb describe-table`.
- [ ] CA3: `terraform init -migrate-state` no `aula-05-rds` conclui e
      `aws s3 ls s3://<bucket>/aula-05/` lista `terraform.tfstate`; `terraform.tfstate`
      local fica vazio/sem recursos.
- [ ] CA4: `terraform apply` do `aula-05-rds` cria VPC, 3 subnets (2 privadas em AZs
      diferentes), IGW, RDS PostgreSQL 15 `db.t3.micro` e EC2 `t2.micro` sem erro;
      `terraform output` mostra `rds_endpoint` e `ec2_public_ip`.
- [ ] CA5: Dado o EC2 provisionado, quando executo
      `psql -h <endpoint> -U <user> -d <db> -c "SELECT version();"` de dentro do EC2,
      então retorna a versão do PostgreSQL (prova EC2 → RDS na 5432).
- [ ] CA6: Após `CREATE TABLE orders (...)` + `INSERT`, `SELECT * FROM orders;`
      retorna as linhas inseridas.
- [ ] CA7: Tentar `psql` para o endpoint do RDS a partir de fora da VPC falha
      (timeout) — banco não exposto.
- [ ] CA8: `terraform plan` no `aula-05-rds` após o apply mostra
      "No changes. Your infrastructure matches the configuration."
- [ ] CA9: `git status` nos dois módulos não lista `*.tfstate`, `*.tfvars`, `*.pem`
      nem `aws-creds.sh` (todos ignorados).
- [ ] CA10: `entregas/aula-05/6325149/entrega.md` existe no branch
      `entregas/aula-05/6325149`, segue o modelo do TF.md e contém as evidências
      CA3, CA5 e CA6 coladas.
- [ ] CA11: Após o teardown, `terraform state list` retorna vazio nos dois módulos,
      `aws rds describe-db-instances` não lista `technova-db`, e
      `aws s3 ls | grep technova` não retorna o bucket.
- [ ] CA12: `aula-05/README.md` do portfólio contém as três reflexões pedidas
      (design da rede, remote state, Spec-Driven vs manual) — texto próprio, não template.

## 7. Riscos e questões em aberto

- **R1 — Permissões do `voclabs`:** o role do Learner Lab pode barrar algum recurso
  (visto na aula-04 com IAM Role). RDS, VPC, S3 e DynamoDB são normalmente liberados;
  se algo for negado, registrar e ajustar no Plan.
- **R2 — `engine_version = "15"`:** verificado em us-east-1 — o provider aws ~>5.0
  aceita a major por prefixo (15.13…15.19 disponíveis) sem drift no `plan`.
- **R3 — Janela de sessão do Learner Lab (~4 h):** o ciclo apply → evidência →
  destroy do RDS gasta ~20–30 min. Se a sessão expirar no meio, o state remoto no S3
  preserva o progresso, mas as credenciais precisam ser renovadas.
- **R4 — Ordem de destroy:** o bucket S3 precisa ser esvaziado (inclusive versões)
  antes do `terraform destroy` do backend, senão falha. Script de esvaziamento no Plan.
- **R5 — Chave SSH:** rodar `ssh-keygen` antes do `apply` do `aula-05-rds`
  (a máquina não tem `~/.ssh/technova-key` ainda).
- **Q2 — Pasta única ou duas?** A spec segue o lab: `aula-05-backend/` e `aula-05-rds/`
  separadas. No PR/portfólio elas convivem dentro de `aula-05/`. OK?
