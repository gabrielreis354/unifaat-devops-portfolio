# Análise: Docker Registry (Amazon ECR) e IA no CI/CD (Aula 09)

Pipeline da TechNova API: a imagem é publicada no **Amazon ECR** pelo script [`ecr-push.sh`](ecr-push.sh) (Learner Lab, `us-east-1`); o CI ([`ci-aula08.yml`](../.github/workflows/ci-aula08.yml): `lint → test → build → push-image`), o [`ai-review.yml`](../.github/workflows/ai-review.yml) e o [`security-scan.yml`](../.github/workflows/security-scan.yml) rodam em Pull Requests. A aplicação usada no build do ECR está em [`technova-api/`](technova-api/).

## 0. Por que Amazon ECR (e as restrições do Learner Lab)

| Critério | Amazon ECR | ghcr.io | Docker Hub |
|----------|-----------|---------|------------|
| Onde a infra roda | **mesma conta AWS** (EC2/ECS/EKS puxam direto) | fora da AWS | fora da AWS |
| Visibilidade padrão | **privado** | privado (pode ficar público) | público no plano grátis |
| Scan de vulnerabilidades | integrado (*scan on push*) | não nativo | pago/limitado |
| Custo | ~US$ 0,10/GB/mês (centavos; coberto pelo crédito do Lab) | grátis | grátis com limites |
| Autenticação | `aws ecr get-login-password` (token de ~12 h) | `GITHUB_TOKEN` | usuário/PAT |

O ECR foi escolhido porque o deploy dos próximos módulos acontece na AWS: a imagem fica ao lado de onde vai rodar e o controle de acesso é o da própria conta. Restrições do **Learner Lab** que moldaram a solução:

- **Credenciais temporárias** (`aws_access_key_id` + `aws_secret_access_key` + `aws_session_token`) que expiram quando a sessão encerra. Por isso o fluxo principal é um **script local**, não um CI com secrets (o `ci.yml` opcional da Parte 7 exigiria atualizar três secrets a cada sessão).
- **Região fixa `us-east-1`.**
- **Sem IAM:** não se cria usuário/role; a autenticação usa a role `voclabs` da sessão. O script recusa rodar como `root`.
- **Sem Bedrock:** ver seção 3.
- **Custo:** o repositório só existe durante a sessão e é apagado com `delete-repository --force` ao fim (regra de não deixar recurso ativo).

## 1. Estratégia de tagging

Imagem no ECR: `<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/technova-api` (publicada pelo `ecr-push.sh`). O CI também publica no `ghcr.io/gabrielreis354/technova-api` como complemento (mesma política de tags).

| Evento | Tags publicadas | Por quê |
|--------|-----------------|---------|
| qualquer build publicado (script) / push na `main` (CI ghcr.io) | `sha-a1b2c3d`, `latest` | O SHA liga a imagem ao commit exato (rastreabilidade e rollback preciso); `latest` é só conveniência |
| git tag `v1.2.3` | `1.2.3`, `1.2`, `1` (+ `sha-…`) | Releases comunicáveis; quem quer só correções fixa `1.2`, quem aceita features fixa `1` |
| pull request | **nenhuma** (job `push-image` fica *skipped*) | PR é código não revisado: não pode gerar imagem no registry |

- **Produção deve usar SHA ou semver completo.** `latest` muda a cada merge e não diz qual código está rodando; serve para desenvolvimento.
- **Rollback** é um `docker pull`/`docker run` com a tag anterior (`1.0.1` → `1.0.0`), sem rebuild.
- **Tags mutáveis no ECR:** `latest`, `1.0` e `1` precisam se mover a cada release; já `sha-…` e `X.Y.Z` nunca devem ser reescritas. (Tags imutáveis no repositório impediriam mover `latest`.)
- **Semver a partir do git:** o `ecr-push.sh` lê a tag `vX.Y.Z` do `HEAD` (`git tag --points-at HEAD`) e deriva `X.Y.Z`, `X.Y` e `X`; sem tag, publica só `sha-…` e `latest`.
- **Limpeza:** *lifecycle policy* expira imagens sem tag após 1 dia e mantém só as 10 mais recentes.
- **Push condicional** é feito com `if: github.event_name == 'push'` no job; as tags de PR nunca existem.
- **Autenticação no ECR:** token temporário do `aws ecr get-login-password` (usuário `AWS`), sem senha fixa. **No CI (ghcr.io):** `GITHUB_TOKEN` com `permissions: packages: write` só no job `push-image`. Ele é gerado por run, limitado ao repositório e expira ao fim do workflow; um PAT seria uma credencial de longa duração com escopo maior.
- **Cache de layers:** `cache-from/to: type=gha` no `build-push-action`, para o push demorar menos.

## 2. Padrões que o AI review verifica

Só as linhas **adicionadas** no diff são analisadas. Cada achado traz arquivo, linha real e trecho de código.

| # | Padrão | Severidade |
|:-:|--------|:----------:|
| 1 | Secret/credencial hardcoded (`password`, `secret`, `apiKey`, `token` = string literal) | 🔴 CRITICAL |
| 2 | `eval()` | 🔴 CRITICAL |
| 3 | Command injection (`exec(\`… ${var}\`)`) | 🔴 CRITICAL |
| 4 | SQL injection (SQL concatenado ou interpolado) | 🔴 CRITICAL |
| 5 | Chave de acesso AWS (`AKIA…`) | 🔴 CRITICAL |
| 6 | Chave privada (`BEGIN … PRIVATE KEY`) | 🔴 CRITICAL |
| 7 | `console.log/debug/info` | 🟡 WARNING |
| 8 | `catch` vazio | 🟡 WARNING |
| 9 | Bind em `0.0.0.0` | 🟡 WARNING |
| 10 | URL `http://` (sem TLS) hardcoded | 🟡 WARNING |
| 11 | `TODO/FIXME/HACK/XXX` | 🔵 INFO |

O `security-scan.yml` é um segundo olhar, focado em segurança: secrets (AWS key, password, chave privada, JWT secret) e o Dockerfile (`USER`, `FROM :latest`, `HEALTHCHECK`).

**Arquivos ignorados:** o próprio `ai-review.js` e seu teste, `*.md` e `package-lock.json`. Sem isso o PR que adiciona o script se bloquearia sozinho, porque o código dele cita `eval(`, `password`, etc. como padrões procurados.

## 3. Lógica e prompt usados na análise

**Fluxo:** PR aberto/atualizado → `git diff origin/<base>...HEAD` → `ai-review.js` classifica → comentário no PR (criado na primeira vez, **atualizado** nos pushes seguintes, procurando o marcador `## 🤖 AI Code Review - TechNova`) → quality gate.

**Nesta entrega a "IA" é baseada em regras** (pattern matching), sem chamada a um modelo de linguagem. O **Bedrock não está disponível no AWS Academy Learner Lab** (confirmado pelo professor): o serviço exige habilitar modelos e criar roles de serviço, o que o Lab bloqueia. Testei antes de descartar: com a sessão `voclabs` (não root), `bedrock:ListFoundationModels` e `bedrock:InvokeModel` retornaram *AccessDenied* ("no identity-based policy allows…") em `us-east-1`, `us-west-2` e `us-east-2`, para 20 modelos de 6 provedores. Portanto a Opção A (regras) é a abordagem da entrega e a Opção B é só referência conceitual.

O prompt que o script enviaria a um modelo, em um ambiente com Bedrock (referência conceitual, **não executado** no Lab), seria:

```text
Você é um revisor de código experiente. Analise o diff de um Pull Request e identifique:
1. Problemas de SEGURANÇA (CRITICAL): secrets, injection, vulnerabilidades
2. Problemas de QUALIDADE (WARNING): code smells, padrões ruins, performance
3. SUGESTÕES (INFO): melhorias opcionais, boas práticas
Para cada achado informe: arquivo e linha, severidade, descrição e sugestão de correção.
Responda em Markdown, com uma tabela. Considere apenas as linhas adicionadas.

<diff>…</diff>
```

Um modelo entenderia a intenção (por exemplo, uma variável vinda do usuário que chega numa query) e acharia menos falsos positivos em texto, mas seria não determinístico, mais lento e pago. As regras são previsíveis, gratuitas e testáveis: o script tem 28 testes (`node --test`) que rodam no próprio workflow antes da análise.

## 4. Quality gate

| Severidade | O que o pipeline faz | O que o dev faz |
|:----------:|----------------------|-----------------|
| 🔴 CRITICAL | posta o comentário e **falha o check** (`exit 1`) | corrige antes do merge |
| 🟡 WARNING | posta o comentário, check verde | corrige se fizer sentido |
| 🔵 INFO | posta o comentário, check verde | opcional |

- O comentário é publicado **antes** do `exit 1`: o dev vê o porquê do bloqueio.
- O script nunca falha por achados; quem decide é um step separado, que lê `critical=true|false`.
- Se a **análise em si** falhar (diff ilegível, erro no script), o check também falha (Fail Fast): um erro nunca vira "tudo certo".
- "Bloqueia" aqui é o **check vermelho** no PR. Torná-lo obrigatório para o merge exigiria uma branch protection; o professor confirmou que, nesta entrega, basta o check vermelho.

## 5. Quando confiar na IA e quando exigir revisão humana

**A IA (regras) é melhor que humanos em:** tarefas repetitivas e exaustivas (secrets, `eval`, `console.log`, `catch` vazio em todo o diff), consistência 24/7, feedback em segundos, PRs grandes onde o revisor cansa.

**Só humano revisa bem:** regras de negócio (o cálculo do pedido está certo?), decisões de arquitetura, design de API, UX, e a justificativa de uma exceção (por exemplo, um `0.0.0.0` intencional em container).

**Confiar para bloquear:** achados determinísticos e sem ambiguidade (chave AWS, chave privada).
**Exigir olho humano:** WARNING/INFO, achados em testes ou exemplos, e qualquer CRITICAL contestado. O dev deve poder justificar e pedir override: o bloqueio é uma trava de segurança, não a palavra final.

## 6. Limitações identificadas

- **Falsos positivos:** na primeira execução, o próprio PR do pipeline recebeu 2 WARNINGs de `console.log` que estavam dentro de um `github-script` num arquivo YAML; as regras de `console.log` e `catch` vazio passaram a valer só em arquivos de código (`.js/.ts`). Além disso, `password = 'exemplo'` num teste ou fixture dispara CRITICAL; por isso há lista de arquivos ignorados.
- **Falsos negativos:** a regra de secret só vê literais entre aspas; uma credencial montada por concatenação ou codificada em base64 passa. SQL injection só é pega quando a string SQL aparece na mesma linha do `+`/`${}`; uma query montada em várias linhas escapa.
- **Contexto limitado:** vê só o diff, não o sistema: não sabe se uma variável vem de input do usuário, se há sanitização mais acima ou se o `console.log` é um logger de verdade.
- **Não entende lógica de negócio:** um bug de cálculo com sintaxe perfeita passa.
- **Falso senso de segurança:** "review passou" não é "código seguro".
- **Complementar às ferramentas tradicionais:** Dependabot (dependências), CodeQL (fluxo de dados), Trivy (vulnerabilidades da imagem).
- **Custo/latência (no caso de modelo):** cobrança por token e 10–60 s de resposta. Com regras é instantâneo e gratuito.
- **Problemas encontrados no script do laboratório e corrigidos:** o número de linha era o do diff (não o do arquivo); a regex com flag `/g` guarda estado entre chamadas (`lastIndex`); um SQL montado numa variável (`const q = 'SELECT … ' + id`) não era detectado; o script se auto-bloqueava ao entrar num PR.

## 7. Segurança da imagem (Trivy)

Além do AI review do código, a imagem foi escaneada com o **Trivy** (`aquasec/trivy`, via Docker) antes de publicar. O Trivy não dá nota em letra (como o Docker Scout); usei como critério de "score A" **zero vulnerabilidades HIGH/CRITICAL** e zero secrets na imagem final.

| Momento | Alpine (libssl3/libcrypto3) | npm embutido na base (tar, minimatch, glob…) | Total HIGH/CRITICAL |
|---------|:---:|:---:|:---:|
| Dockerfile inicial | 4 | 23 (1 CRITICAL) | **27** |
| Após `apk upgrade` + remoção do npm/npx | 0 | 0 | **0** (e 0 de qualquer severidade, 0 secrets) |

Correção no [`Dockerfile`](technova-api/Dockerfile): o estágio de runtime roda `apk upgrade --no-cache` e remove `/usr/local/lib/node_modules/npm`, `npm` e `npx`, porque a imagem só executa `node server.js` e o npm da imagem base carregava as dependências vulneráveis. `trivy config` no Dockerfile: 0 misconfigurações. Efeito colateral aceito: a imagem não tem mais npm (não é possível `npm install` dentro do container, o que é desejável em produção).

## 8. Evidências da execução (Learner Lab, 23/10/2026)

Identidade: `assumed-role/voclabs` (não root), região `us-east-1`. O repositório ECR foi **destruído** (`delete-repository --force`) depois da coleta; `describe-repositories` retornou `[]`.

| Item | Resultado |
|------|-----------|
| Repositório | `technova-api`, `scanOnPush=True`, tags mutáveis |
| Lifecycle policy | 2 regras: expira imagens sem tag após 1 dia; mantém as 10 imagens com tag mais recentes |
| `v1.0.0` (commit `499d3ff`) | tags `1.0.0`, `1.0`, `1`, `latest`, `sha-499d3ff` |
| `v1.0.1` (commit `4a7900e`) | tags `1.0.1`, `1.0`, `1`, `latest`, `sha-4a7900e` (digest `a16a6eb6…`); `1.0.0` ficou só com `1.0.0` e `sha-499d3ff` (digest `2c2f7a15…`) |
| Pull/run/`/health` | `1.0.1` → HTTP 200; rollback para `1.0.0` → HTTP 200; usuário `technova` |
| Scan do ECR (`1.0.1`) | `COMPLETE`, 0 achados |

**Problema encontrado e corrigido (PR #8):** a `1.0.0` foi publicada como **índice OCI** (a imagem mais um manifesto de attestation, comportamento padrão do Docker 29), e o ECR recusou o scan com `UnsupportedImageTypeException`. O script passou a usar `docker build --provenance=false --sbom=false`; a `1.0.1` é uma imagem simples e foi escaneada. A `1.0.0` continua usável para pull e rollback, mas não é escaneável.

**Observação:** o `/health` da `1.0.1` ainda reporta `"version":"1.0.0"`, porque o `server.js` lê `npm_package_version`, que só existe quando o app roda via `npm start` (a imagem usa `node server.js`). Quem distingue as versões são as tags e os digests.

**AI review e quality gate** (PR de demonstração [#9](https://github.com/gabrielreis354/unifaat-devops-portfolio/pull/9), fechado sem merge): 1º push com `console.log`, catch vazio e TODO → 3 achados, 0 CRITICAL, checks verdes. 2º push com secrets, SQL injection e `eval()` → 7 achados (4 CRITICAL), o **mesmo comentário foi atualizado** e os checks `AI Code Review` e `Security Scan` falharam.

| Print | Arquivo |
|-------|---------|
| Console do ECR com as tags | [`screenshots/ecr-console.png`](screenshots/ecr-console.png) |
| `ecr-push.sh` concluído | [`screenshots/ecr-push-ok.png`](screenshots/ecr-push-ok.png) |
| Comentário do AI review | [`screenshots/ai-review-comment.png`](screenshots/ai-review-comment.png) |
| Quality gate bloqueando | [`screenshots/quality-gate-block.png`](screenshots/quality-gate-block.png) |
