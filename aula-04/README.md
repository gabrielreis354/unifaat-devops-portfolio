# Infraestrutura TechNova — Aula 04

VPC + EC2 **Multi-AZ** provisionada com Terraform, pronta para alta disponibilidade
(preparada para receber um Load Balancer no futuro). Aluno: **Gabriel Reis Cunha (RA: 6325149)**.

## Diagrama da Arquitetura

```
                              Internet
                                 │
                        ┌────────┴────────┐
                        │ Internet Gateway│
                        └────────┬────────┘
                                 │  (Route Table pública: 0.0.0.0/0 → IGW)
        ┌────────────────────────┼────────────────────────┐
        │  VPC technova-vpc  10.0.0.0/16                    │
        │                                                   │
        │   AZ a                          AZ b              │
        │  ┌───────────────────┐   ┌───────────────────┐   │
        │  │ public-1          │   │ public-2          │   │
        │  │ 10.0.1.0/24       │   │ 10.0.3.0/24       │   │
        │  │  ┌─────────────┐  │   │                   │   │
        │  │  │ EC2 t2.micro│  │   │  (reservada p/    │   │
        │  │  │ API :3000   │  │   │   HA / LB futuro) │   │
        │  │  │ SG: api     │  │   │                   │   │
        │  │  └─────────────┘  │   │                   │   │
        │  └───────────────────┘   └───────────────────┘   │
        │  ┌───────────────────┐   ┌───────────────────┐   │
        │  │ private-1         │   │ private-2         │   │
        │  │ 10.0.2.0/24       │   │ 10.0.4.0/24       │   │
        │  │ (DB futuro,       │   │ (DB futuro)       │   │
        │  │  SG: db :5432 VPC)│   │                   │   │
        │  └───────────────────┘   └───────────────────┘   │
        │        (subnets privadas: Route Table padrão,     │
        │         somente rota local, sem saída p/ internet)│
        └───────────────────────────────────────────────────┘

  Fluxo IAM (service role):  EC2 → Instance Profile → Role → AmazonS3ReadOnlyAccess
```

## Como usar

### Pré-requisitos
- **AWS CLI** configurado (no laboratório: AWS Academy Learner Lab, role `voclabs`)
- **Terraform** >= 1.0
- Providers usados: `hashicorp/aws ~> 5.0`, `hashicorp/tls ~> 4.0`, `hashicorp/local ~> 2.0`
- A **chave SSH é criada pelo próprio Terraform** (`tls_private_key` + `aws_key_pair`),
  salva como `technova-key.pem` (0400, fora do git).

### Comandos
```bash
terraform init            # baixa os providers
terraform fmt             # formata os .tf
terraform validate        # valida sintaxe e referências
terraform plan            # mostra os recursos a criar (evidência)
terraform apply           # cria a infraestrutura
terraform destroy         # remove tudo após capturar as evidências
```

> **AWS Academy Learner Lab:** o role `voclabs` não permite criar IAM Role. Use a flag
> para reaproveitar o profile existente do lab:
> `terraform apply  -var="create_iam_role=false"`
> `terraform destroy -var="create_iam_role=false"`
> O `terraform plan` (padrão, `create_iam_role=true`) comprova a criação da Role/Profile
> própria exigida pelo enunciado.

### Como testar
```bash
IP=$(terraform output -raw ec2_public_ip)
curl http://$IP:3000          # info da API
curl http://$IP:3000/health   # {"status":"healthy",...}
curl http://$IP:3000/orders   # lista de pedidos

# SSH (a API roda como serviço systemd technova-api):
ssh -i technova-key.pem ec2-user@$IP
#   node --version
#   aws sts get-caller-identity   # mostra a Role, sem access keys
```

### Como destruir
```bash
terraform destroy -var="create_iam_role=false"   # no Learner Lab
```

## Decisões técnicas

- **Multi-AZ (2 AZs):** as 4 subnets se distribuem em duas Availability Zones. Se uma AZ
  cair, a arquitetura continua tendo capacidade na outra — é o pré-requisito para alta
  disponibilidade e para colocar um Load Balancer na frente de instâncias em AZs distintas.
- **Separação público/privado:** só as subnets públicas têm rota para o IGW e
  `map_public_ip_on_launch`. Recursos sensíveis (banco, cache) ficam nas privadas, sem
  rota de saída para a internet — reduz a superfície de ataque.
- **Security Groups com menor privilégio:** o SG da API expõe apenas 22 e 3000; o SG do
  banco só aceita 5432 **de dentro da VPC** (`10.0.0.0/16`), nunca da internet.
- **`for_each` + `locals` para as subnets:** evita repetição (DRY) e deixa trivial
  adicionar/remover subnets — cada uma é declarada uma vez num mapa.
- **Instance Profile (não access keys):** a EC2 recebe credenciais temporárias via role,
  eliminando chaves estáticas no código. A flag `create_iam_role` concilia o enunciado
  (criar a role) com a restrição do Learner Lab (reutilizar `LabInstanceProfile`).
- **AMI via data source:** `al2023-ami-2023.*-x86_64` do owner `amazon`, sempre a mais
  recente — sem fixar ID que envelhece.
- **User Data idempotente + systemd:** a API sobe como serviço `technova-api`, resistente
  a reboot, com log em `/var/log/technova-setup.log`.

## Recursos criados

| Recurso | Nome | Função |
|---------|------|--------|
| `aws_vpc` | technova-vpc | Rede isolada 10.0.0.0/16 |
| `aws_subnet` (public ×2) | technova-public-1/2 | Subnets públicas (AZ a/b) para a API |
| `aws_subnet` (private ×2) | technova-private-1/2 | Subnets privadas (AZ a/b) para o banco futuro |
| `aws_internet_gateway` | technova-igw | Saída para a internet |
| `aws_route_table` + assoc. | technova-public-rt | Rota 0.0.0.0/0 → IGW nas 2 públicas |
| `aws_security_group` (api) | technova-api-sg | Libera 22 e 3000 |
| `aws_security_group` (db) | technova-db-sg | Libera 5432 apenas da VPC |
| `aws_key_pair` + `tls_private_key` | technova-key | Chave SSH criada via Terraform |
| `aws_iam_role` + attachment + `aws_iam_instance_profile` | technova-ec2-role/-profile | Role EC2 com AmazonS3ReadOnlyAccess |
| `aws_instance` | technova-api | EC2 t2.micro com a API Node.js na 3000 |

## Evidências

- `terraform-plan-output.txt` — `Plan: 18 to add` (inclui a IAM Role própria).
- `evidencia-api.txt` — respostas reais de `/`, `/health` e `/orders` com a API rodando na AWS.
- Ciclo executado no Learner Lab: `apply` (15 recursos) → API respondendo → `destroy`
  (15 destruídos). Nenhum recurso deixado ativo.
