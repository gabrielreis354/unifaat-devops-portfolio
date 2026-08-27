# Aula 03 — Terraform + IAM | Gabriel Reis Cunha (RA: 6325149)

Estrutura completa de IAM da TechNova gerenciada como código (Terraform), aplicando
o princípio do menor privilégio com groups, users, custom policies e uma service role.

## Design da Estrutura IAM

A estrutura foi desenhada em torno de **groups por responsabilidade** (nunca anexando
policy direto no user), para que a permissão seja função do *papel* da pessoa e a
manutenção seja trivial quando alguém entra, sai ou muda de time.

- **`6325149-technova-developers`** — devs que só precisam **ler** dados no S3. Recebe a
  policy de leitura (`s3-read`) e, como camada extra de segurança, a policy de **Deny
  explícito** de ações destrutivas.
- **`6325149-technova-platform-eng`** — engenharia de plataforma, que **opera** EC2 e
  faz leitura/escrita no S3. Recebe a policy `ec2-s3-full`.

**Users e memberships:**

| User | Groups | Racional |
|------|--------|----------|
| `6325149-juliana-dev` | developers | Dev sênior — leitura de S3 |
| `6325149-rafael-platform` | developers + platform-eng | Atua nos dois papéis |
| `6325149-lucas-intern` | developers | Estagiário — somente leitura |

Rafael está nos dois groups de propósito: ele herda o poder de operar EC2/S3 do
platform-eng, mas **continua sujeito ao Deny explícito** herdado do group developers —
ou seja, nem ele consegue executar `Terminate`/`Delete`. É defesa em profundidade.

**Service role (EC2 → S3):** a role `6325149-technova-ec2-role` tem trust policy para
`ec2.amazonaws.com` e permissão de read/write **restrita** ao bucket `technova-app-data-*`.
A aplicação usa o **instance profile** `6325149-technova-ec2-profile` — assim a API roda
com credenciais temporárias e roladas automaticamente, **sem chaves estáticas no código**.

## Princípio do Menor Privilégio

**O que é:** conceder a cada identidade *exatamente* as permissões necessárias para a
sua tarefa — nada além. Reduz o raio de impacto de uma credencial vazada ou de um erro humano.

**Como apliquei (2 exemplos):**

1. **Actions e Resources específicos, não `*`.** A policy `s3-read` permite apenas
   `s3:ListBucket` e `s3:GetObject`, e somente nos buckets `technova-*` (List no ARN do
   bucket, Get no ARN do objeto — statements separados). O estagiário não consegue ler
   buckets de outros projetos nem escrever/apagar nada.

2. **Condition por tag no controle de EC2.** Em `ec2-s3-full`, o `StartInstances`/
   `StopInstances` só é permitido quando `aws:ResourceTag/Project = TechNova`. Mesmo o
   platform-eng não liga/desliga instâncias de outros times.

**E se eu usasse `AmazonS3FullAccess` em vez da custom policy?** Todo mundo do group
ganharia `s3:*` em **todos** os buckets da conta — incluindo `DeleteObject`,
`DeleteBucket` e `PutBucketPolicy` em recursos que não são do projeto. Um estagiário
poderia apagar um bucket de produção de outro time por engano (exatamente o incidente
descrito no cenário da TechNova), e uma auditoria não conseguiria justificar *por que*
aquela permissão existe. A custom policy torna a intenção explícita e auditável.

## Diagrama de Permissões

```
AWS Account (root NUNCA usado diretamente)
│
├── Group: 6325149-technova-developers
│   ├── Users: juliana-dev, rafael-platform, lucas-intern
│   ├── Policy: s3-read ............ (Allow: s3:ListBucket, s3:GetObject em technova-*)
│   └── Policy: deny-destructive ... (Deny: Delete*/Terminate* — prevalece sobre Allow)
│
├── Group: 6325149-technova-platform-eng
│   ├── Users: rafael-platform
│   └── Policy: ec2-s3-full ........ (Allow: ec2:Describe*, Start/Stop [tag=TechNova],
│                                     s3:List/Get/Put em technova-*)
│
└── Role: 6325149-technova-ec2-role
    ├── Trust Policy: ec2.amazonaws.com pode assumir (sts:AssumeRole)
    ├── Policy: ec2-app-data ........ (Allow: s3:List/Get/Put em technova-app-data-*)
    └── Instance Profile: 6325149-technova-ec2-profile → anexado à EC2

Fluxo de acesso:  User → Group → Policy → Recursos
Fluxo do serviço: EC2 → Instance Profile → Role → Policy → S3 (technova-app-data-*)
```

## Comandos Utilizados

```bash
terraform init      # baixa o provider AWS (~> 5.0)
terraform fmt       # formata os arquivos .tf
terraform validate  # valida a sintaxe e as referências
terraform plan      # mostra os recursos que serão criados (evidência)
terraform apply     # cria os recursos na AWS
terraform destroy   # remove tudo após capturar a evidência
```

## Reflexão — Console AWS (manual) vs. Terraform

Criar IAM pelo **Console** é rápido para uma pessoa, mas não escala e não é auditável:
não há registro do *porquê* de cada permissão, recriar em outra conta (staging/prod) é
manual e sujeito a divergência, e reverter um erro depende de alguém lembrar o que
clicou. Quando a equipe cresce, vira uma colcha de permissões impossível de revisar.

Com **Terraform**, a estrutura de acesso é **código versionado**: cada mudança passa por
commit/PR e code review, o `plan` mostra o impacto **antes** de aplicar, e o mesmo código
recria o ambiente idêntico em qualquer conta. Numa auditoria, o repositório *é* a
documentação. Para uma equipe, é incomparavelmente mais **seguro** (revisável, com Deny
explícito garantido) e **auditável** (histórico completo no git) do que cliques no Console.

---

> **Observação técnica:** IAM *groups*, *memberships* e *policy attachments* não suportam
> tags na AWS — por isso as tags obrigatórias (`Project`, `ManagedBy`, `Aluno`, `RA`,
> `Disciplina`, `Aula`) são aplicadas em todos os recursos que as suportam: **users,
> policies, role e instance profile**.
