# Análise: Docker Registry e IA no CI/CD (Aula 09)

Pipeline da TechNova API: `lint → test → build → push-image` ([`ci-aula08.yml`](../.github/workflows/ci-aula08.yml)), mais [`ai-review.yml`](../.github/workflows/ai-review.yml) e [`security-scan.yml`](../.github/workflows/security-scan.yml) em todo Pull Request. A API continua em [`aula-08/technova-api/`](../aula-08/technova-api/): o professor pediu que a versão corrente do projeto evolua no mesmo lugar a cada aula.

## 1. Estratégia de tagging

Imagem: `ghcr.io/gabrielreis354/technova-api`.

| Evento | Tags publicadas | Por quê |
|--------|-----------------|---------|
| push na `main` | `sha-a1b2c3d`, `latest` | O SHA liga a imagem ao commit exato (rastreabilidade e rollback preciso); `latest` é só conveniência |
| git tag `v1.2.3` | `1.2.3`, `1.2`, `1` (+ `sha-…`) | Releases comunicáveis; quem quer só correções fixa `1.2`, quem aceita features fixa `1` |
| pull request | **nenhuma** (job `push-image` fica *skipped*) | PR é código não revisado: não pode gerar imagem no registry |

- **Produção deve usar SHA ou semver completo.** `latest` muda a cada merge e não diz qual código está rodando; serve para desenvolvimento.
- **Rollback** é um `docker run` com a tag anterior (`1.0.1` → `1.0.0`), sem rebuild.
- **Push condicional** é feito com `if: github.event_name == 'push'` no job; as tags de PR nunca existem.
- **Autenticação:** `GITHUB_TOKEN` com `permissions: packages: write` só no job `push-image`. Ele é gerado por run, limitado ao repositório e expira ao fim do workflow; um PAT seria uma credencial de longa duração com escopo maior.
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

**Nesta entrega a "IA" é baseada em regras** (pattern matching), sem chamada a um modelo de linguagem. A decisão foi do professor: a Opção A do laboratório é suficiente; o Bedrock via Learner Lab seria opcional. Não usei porque ele cobra por token e o CI precisaria de credenciais temporárias do Learner Lab, que expiram a cada sessão.

O prompt que o script enviaria a um modelo (Bedrock/Claude) seria:

```text
Você é um revisor de código experiente. Analise o diff de um Pull Request e identifique:
1. Problemas de SEGURANÇA (CRITICAL): secrets, injection, vulnerabilidades
2. Problemas de QUALIDADE (WARNING): code smells, padrões ruins, performance
3. SUGESTÕES (INFO): melhorias opcionais, boas práticas
Para cada achado informe: arquivo e linha, severidade, descrição e sugestão de correção.
Responda em Markdown, com uma tabela. Considere apenas as linhas adicionadas.

<diff>…</diff>
```

Um modelo entenderia a intenção (por exemplo, uma variável vinda do usuário que chega numa query) e acharia menos falsos positivos em texto, mas seria não determinístico, mais lento e pago. As regras são previsíveis, gratuitas e testáveis: o script tem 27 testes (`node --test`) que rodam no próprio workflow antes da análise.

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

- **Falsos positivos:** `password = 'exemplo'` num teste ou fixture dispara CRITICAL; por isso há lista de arquivos ignorados.
- **Falsos negativos:** a regra de secret só vê literais entre aspas; uma credencial montada por concatenação ou codificada em base64 passa. SQL injection só é pega quando a string SQL aparece na mesma linha do `+`/`${}`; uma query montada em várias linhas escapa.
- **Contexto limitado:** vê só o diff, não o sistema: não sabe se uma variável vem de input do usuário, se há sanitização mais acima ou se o `console.log` é um logger de verdade.
- **Não entende lógica de negócio:** um bug de cálculo com sintaxe perfeita passa.
- **Falso senso de segurança:** "review passou" não é "código seguro".
- **Complementar às ferramentas tradicionais:** Dependabot (dependências), CodeQL (fluxo de dados), Trivy (vulnerabilidades da imagem).
- **Custo/latência (no caso de modelo):** cobrança por token e 10–60 s de resposta. Com regras é instantâneo e gratuito.
- **Problemas encontrados no script do laboratório e corrigidos:** o número de linha era o do diff (não o do arquivo); a regex com flag `/g` guarda estado entre chamadas (`lastIndex`); um SQL montado numa variável (`const q = 'SELECT … ' + id`) não era detectado; o script se auto-bloqueava ao entrar num PR.
