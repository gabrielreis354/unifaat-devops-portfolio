# Respostas — Aula 08: GitHub Actions e CI Pipelines

**Aluno:** Gabriel Reis Cunha
**RA:** 6325149

Cada resposta traz a alternativa correta, o porquê, a análise das erradas e onde isso aparece no pipeline deste repositório ([`.github/workflows/ci-aula08.yml`](../.github/workflows/ci-aula08.yml)).

---

## Questão 1 — O que dispara a execução de um workflow do GitHub Actions?

**Resposta: b)** Eventos configurados no campo `on:` do YAML, como `push`, `pull_request` ou `workflow_dispatch`.

**Por quê:** um workflow é *orientado a eventos*. O GitHub observa o repositório e, quando ocorre um evento listado em `on:` (e que passa pelos filtros `branches`/`paths`), cria uma execução em um runner novo. Sem evento correspondente, nada roda.

**Por que as outras estão erradas:**
- **a)** O GitHub não executa nada "a cada 5 minutos" por padrão. Execução periódica só existe se o workflow declarar explicitamente `schedule:` com um `cron` (e o intervalo mínimo é de 5 minutos, mas precisa ser configurado).
- **c)** Clicar em "Run workflow" só é possível quando o workflow declara `workflow_dispatch`; é uma das formas de disparo, não a regra.
- **d)** Não há papel de "administrador faz deploy" como gatilho: qualquer evento configurado dispara, sem intervenção humana.

**No nosso pipeline:** `on:` define `push` na `main`, `pull_request` para a `main` e `workflow_dispatch`, com `paths` limitando a `aula-08/**` e ao próprio workflow. Por isso o run do PR #1 disparou sozinho no `pull_request`, e o push na `main` após o merge disparou o run da `main`.

---

## Questão 2 — Qual é a função da keyword `needs` em um workflow multi-stage?

**Resposta: c)** Cria dependência entre jobs: o job só executa se os jobs listados em `needs` terminarem com sucesso.

**Por quê:** por padrão, os jobs de um workflow rodam **em paralelo**, cada um em um runner isolado. `needs` define a ordem (um grafo de dependências): o job espera os anteriores e, se algum falhar ou for cancelado, ele é **ignorado** (`skipped`). Isso economiza tempo de CI e impede, por exemplo, gerar uma imagem a partir de código reprovado.

**Por que as outras estão erradas:**
- **a)** Secrets são consumidos pelo contexto `secrets` (`${{ secrets.NAME }}`) e pelo bloco `env`, não por `needs`.
- **b)** O runner é escolhido por `runs-on`.
- **d)** Retentativas não são um atributo do `needs`; re-execuções são feitas pelo botão "Re-run jobs" ou por actions específicas.

**No nosso pipeline:** `test` tem `needs: lint` e `build` tem `needs: [lint, test]`. Na prova do R7 (PR #2, com erro de lint intencional) o `lint` falhou e `Tests`, `Build` e o comentário no PR apareceram como `skipped`, exatamente o comportamento do `needs`.

---

## Questão 3 — Onde devem ser armazenadas credenciais AWS para uso em GitHub Actions?

**Resposta: c)** Em GitHub Secrets (Settings → Secrets and variables → Actions), referenciadas com `${{ secrets.NAME }}`.

**Por quê:** secrets são armazenados criptografados, não são exibidos depois de criados (só substituídos ou apagados), não vão para o histórico do Git e são mascarados (`***`) nos logs. Também **não são entregues** a workflows disparados por PRs de forks, o que protege contra PRs maliciosos.

**Por que as outras estão erradas:**
- **a)** Um `.env` commitado fica para sempre no histórico do Git, mesmo se for apagado depois; o GitHub só mascara valores cadastrados como secret, não arquivos do repositório. É o incidente da TechNova: a credencial precisa ser **revogada**, não apenas removida.
- **b)** `runs-on` escolhe o runner, não guarda variáveis, e um `env` com valor literal no YAML também exporia a credencial.
- **d)** Não existe campo `credentials:` para chaves AWS no YAML; colocar valor direto no arquivo equivale a commitar a credencial.

**No nosso pipeline:** o secret `AWS_REGION` (e `APP_ENV`, ambos fictícios) foi cadastrado no repositório e é lido no job `lint` por `env: AWS_DEFAULT_REGION: ${{ secrets.AWS_REGION }}`. O log do run mostra `AWS_REGION=***`. Para credenciais reais, o ideal é ainda preferir OIDC com uma role de menor privilégio em vez de chaves de longa duração.

---

## Questão 4 — Qual é o propósito de environments com approval gates?

**Resposta: b)** Garantir que deploys para ambientes sensíveis (como produção) exijam aprovação humana antes de executar.

**Por quê:** um *environment* (staging, production) agrupa configuração e **regras de proteção**: *required reviewers* (alguém precisa aprovar antes de o job rodar), *wait timer*, restrição de branches de deploy e *environment secrets* (visíveis só para jobs daquele ambiente). Assim, uma credencial de produção só é liberada depois da aprovação e só para a branch autorizada.

**Por que as outras estão erradas:**
- **a)** Approval gate **adiciona** uma espera; não acelera nem paraleliza jobs.
- **c)** Expor secrets nos logs seria o oposto do objetivo: o gate reduz a exposição.
- **d)** Environments não copiam repositórios nem criam servidores; são um contexto de configuração e segurança do próprio GitHub.

**No contexto da TechNova:** o CI deste repositório valida e constrói (lint → test → build). O deploy em produção ficaria em um job separado com `environment: production` e *required reviewers*, de modo que nenhum push chegue à produção sem revisão humana, resolvendo o problema do deploy manual de 32 minutos sem abrir mão do controle.
