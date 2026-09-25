# Aula 05 — RDS + Remote State | Gabriel Reis Cunha (RA: 6325149)

Infraestrutura da TechNova com camada de dados persistente (Amazon RDS PostgreSQL em
subnets privadas) e Terraform state protegido em backend remoto (S3 versionado +
trava de concorrência no DynamoDB).

O projeto tem **dois módulos raiz**:

| Pasta | Responsabilidade |
|-------|------------------|
| [`aula-05/backend/`](backend/) | Bucket S3 + tabela DynamoDB que hospedam o state remoto |
| `aula-05/` (esta pasta) | VPC + RDS + EC2, com `backend "s3"` apontando para o módulo acima |

---

## Design da Estrutura

### Base (`main.tf`)

- `locals.common_tags` (`Project`, `Aula = "05"`), aplicado em **todos** os recursos via
  `merge(local.common_tags, { Name = ... })`.
- Data source das AZs disponíveis, usado pelas subnets.

### Rede (`vpc.tf`)

- **VPC `10.0.0.0/16`** com DNS habilitado.
- **1 subnet pública `10.0.1.0/24`** (AZ `us-east-1a`) — só o EC2 vive aqui. Tem
  `map_public_ip_on_launch = true` e rota `0.0.0.0/0` para o Internet Gateway.
- **2 subnets privadas** `10.0.2.0/24` (`us-east-1a`) e `10.0.4.0/24` (`us-east-1b`) —
  sem rota para a internet. Ficam em **AZs diferentes** porque o *DB Subnet Group* do
  RDS exige cobertura de pelo menos duas AZs.
- O RDS não recebe subnet pública nem `publicly_accessible`, então **não há caminho de
  rede da internet até o banco** — nem via IGW, nem via IP público.

### Banco (`rds.tf`)

- PostgreSQL 15, `db.t3.micro`, 20 GB `gp2`, `storage_encrypted = true`.
- `multi_az = false` e `performance_insights_enabled = false` (fora do Free Tier).
- Credenciais (`db_name`, `username`, `password`) vêm de variáveis; a senha é
  `sensitive = true` e mora no `terraform.tfvars` (fora do Git).
- `skip_final_snapshot = true` — aceitável só porque é um lab efêmero.

### Servidor (`ec2.tf`)

- `t2.micro` na subnet pública, AMI Amazon Linux 2023 (data source `most_recent`).
- `user_data` instala o cliente `postgresql15` — o suficiente para provar a conexão
  EC2 → RDS com `psql`.
- Key pair criado a partir de `~/.ssh/technova-key.pub` (gerado com `ssh-keygen`).

---

## Princípio do Menor Privilégio

**O que é:** cada componente recebe só o acesso estritamente necessário para a sua
função — nada além disso. Reduz a superfície de ataque e o raio de dano de um
vazamento de credencial.

**Como apliquei aqui:**

1. **Security Group do RDS** (`aws_security_group.rds`): a regra de entrada libera a
   porta `5432` **apenas para `cidr_blocks = [var.vpc_cidr]`** (10.0.0.0/16). Nenhuma
   origem externa à VPC alcança o banco. Não abri `0.0.0.0/0` "para facilitar o teste".
2. **Isolamento de rede do banco:** o RDS fica só nas subnets privadas e com
   `publicly_accessible = false`. Mesmo que o Security Group fosse frouxo, não existe
   rota da internet até ele. São duas camadas independentes (rede + SG) barrando o
   mesmo acesso indevido.
3. **Segredos fora do código:** senha do banco em variável `sensitive`, `terraform.tfvars`,
   `*.pem`, `*.tfstate` e `aws-creds.sh` no `.gitignore`.

**E se eu usasse um Security Group aberto (`0.0.0.0/0:5432`) em vez da regra restrita?**
O endpoint do RDS é resolvível e a porta ficaria acessível de qualquer lugar que
tivesse rota até a instância. Combinado com `publicly_accessible = true` (que eu
*não* usei), isso exporia o PostgreSQL à internet inteira — bastaria um scan de porta
e um ataque de dicionário na senha do `technova_admin` para comprometer todos os
dados. A regra por CIDR da VPC transforma "qualquer um na internet" em "somente
recursos dentro da minha rede".

---

## Remote State: por que S3 + DynamoDB

| Problema do state local (`terraform.tfstate` no disco) | Solução no backend remoto |
|---|---|
| Não é compartilhável — cada pessoa tem um state diferente | Bucket S3 único, lido por todo o time |
| Sem histórico — um `apply` errado sobrescreve o arquivo | **Versionamento** do bucket permite rollback |
| Contém segredos em texto claro no repositório/máquina | Bucket privado (**Block Public Access** 4/4) + **encrypt** SSE-KMS |
| Dois `apply` simultâneos corrompem o state | **Lock no DynamoDB** (`LockID`): o segundo `apply` espera ou falha |

O módulo `aula-05/backend` provisiona isso em duas partes:

- **Tabela DynamoDB** (`aws_dynamodb_table`, `hash_key = "LockID"`,
  `billing_mode = "PAY_PER_REQUEST"`) — via Terraform normalmente.
- **Bucket S3** (versionamento + SSE-KMS + Block Public Access 4/4) — via
  **`bootstrap.sh`** (AWS CLI), **não** pelo recurso `aws_s3_bucket`.

  > **Por quê?** O SCP do AWS Academy Learner Lab nega explicitamente
  > `s3:GetBucketObjectLockConfiguration`. O recurso `aws_s3_bucket` do provider
  > `hashicorp/aws` chama essa API em toda leitura/criação/import, e falha com
  > `AccessDenied` **em qualquer versão do provider** (testado `5.100.0` e
  > `5.42.0`) — mesmo assim, `create-bucket`, `put-bucket-versioning`,
  > `put-bucket-encryption` e `put-public-access-block` funcionam normalmente
  > via CLI. `bootstrap.sh` cria e configura o bucket com essas chamadas
  > (idempotente) e imprime o bloco `backend "s3"` pronto para colar;
  > `teardown.sh` esvazia (versões + delete markers) e remove o bucket no fim.

O `aula-05` então declara:

```hcl
terraform {
  backend "s3" {
    bucket         = "technova-terraform-state-<sufixo>"
    key            = "aula-05/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "technova-terraform-locks"
  }
}
```

O bloco `backend` não aceita variáveis, então o nome do bucket (impresso pelo
`bootstrap.sh`) e o nome da tabela (output do `terraform apply` do backend) são
colados manualmente aqui antes do `terraform init` do `aula-05`.

---

## Diagrama

```
 User ──ssh (22)──▶ EC2 (subnet pública, SG ec2: 22, 3000)
                      │
                      │ psql 5432  (origem dentro de 10.0.0.0/16)
                      ▼
                    RDS PostgreSQL  (subnets privadas, SG rds: 5432 da VPC)
                      │  publicly_accessible = false · storage_encrypted = true
                      ▼
                    Dados (tabela orders) — sobrevivem a reboot/replace do EC2

 terraform apply ──▶ state ──▶ s3://technova-terraform-state-<sufixo>/aula-05/terraform.tfstate
                       │                         (versionado, SSE-KMS, sem acesso público)
                       └── lock ──▶ DynamoDB technova-terraform-locks (LockID)
```

---

## Comandos Utilizados

```bash
# chave SSH (uma vez)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/technova-key -N ""

# 1) backend
cd aula-05/backend
source ../../aws-creds.sh
./bootstrap.sh                    # cria o bucket S3 via AWS CLI (imprime o backend "s3")
terraform init && terraform apply # cria so a tabela DynamoDB
#    -> copiar bucket (do bootstrap.sh) e dynamodb_table_name (output) para o backend "s3"

# 2) infra principal
cd ..
cp terraform.tfvars.example terraform.tfvars     # e define a senha
terraform init          # cria o state direto no S3
terraform apply         # VPC + RDS (5-10 min) + EC2

terraform output
terraform plan          # "No changes." apos o apply

# 3) teardown (mesma sessao, logo apos as evidencias)
terraform destroy                               # aula-05
cd backend
./teardown.sh                                   # esvazia e remove o bucket
terraform destroy                               # remove a tabela DynamoDB
```

---

## Reflexão — criação manual (Console) vs. Terraform

Criar VPC, subnets, RDS e Security Groups pelo Console AWS é possível, mas para uma
equipe o Terraform ganha em dois pontos que importam:

- **Auditável:** o `git log` do módulo mostra quem mudou o quê e quando. No Console,
  a única trilha é o CloudTrail, que ninguém revisa no dia a dia.
- **Reprodutível:** `terraform apply` recria a infra idêntica em outra conta/região.
  No Console, é um roteiro de dezenas de cliques que sempre diverge um pouco.

O Console continua útil para **explorar** um serviço novo e para **debug** pontual —
mas a fonte da verdade fica no código.

## Reflexão — Spec-Driven vs. manual (Lab Parte 1 × Parte 2)

O `aula-05` (Lab Parte 1) foi feito seguindo um roteiro passo a passo: previsível,
mas cada arquivo digitado à mão. O `aula-05/backend` (Lab Parte 2) partiu de uma
**Spec** (`../specs/001-aula05-rds-remote-state/`) — objetivo, requisitos e critérios
de aceitação aprovados **antes** de escrever HCL.

- **Spec-Driven** brilha em infra nova, do zero: força a decidir "o que" e "por que"
  (ex.: SSE-KMS vs AES256, `backup_retention_period`) antes de estar preso a uma
  implementação, e os critérios de aceitação viram o checklist de verificação.
- **Manual/iterativo** é melhor para ajuste fino e debugging, quando o contexto já
  está todo na cabeça e a Spec seria burocracia.
- Aceitar código gerado sem validar contra a Spec é o pior dos dois mundos: some a
  disciplina do manual e a rastreabilidade do Spec-Driven.

---

## Evidências

Ver [`entregas/aula-05/6325149/entrega.md`](https://github.com/AleTavares/devops_20262/tree/main/entregas/aula-05/6325149)
no repositório da disciplina:

1. `aws s3 ls` mostrando o `terraform.tfstate` no bucket.
2. `psql ... -c "SELECT version();"` do EC2 para o RDS.
3. `SELECT * FROM orders;` com dados persistentes.
4. `terraform plan` limpo ("No changes").

> Toda a infraestrutura foi destruída (`terraform destroy` + esvaziamento do bucket)
> imediatamente após a captura das evidências — nenhum recurso pago ficou ativo.
