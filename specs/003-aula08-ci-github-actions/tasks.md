# TASKS: TF Aula 08 — CI com GitHub Actions

Legenda: 🤖 = eu executo · 👤 = Gabriel (prints/decisões) · ⚠️ = ação externa, confirmo antes.
Portfólio: `~/unifaat-devops-portfolio` · Disciplina: `/mnt/c/Users/gabri/unifaat_4sem/devops_20262`

## Fase A — Projeto local (portfólio)
- [ ] **T1** 🤖 Criar branch `feature/aula-08-ci-pipeline` a partir da `main`. *Verif.: `git branch --show-current`.*
- [ ] **T2** 🤖 Copiar conteúdo de `technova-api/` da disciplina para `aula-08/` (sem `node_modules`). *Verif.: `ls -a aula-08` mostra server.js, package(-lock).json, Dockerfile, .eslintrc.json, .gitignore, .dockerignore, __tests__/.*
- [ ] **T3** 🤖 `cd aula-08 && npm ci`; rodar `npm run lint`. *Verif.: 0 erros.*
- [ ] **T4** 🤖 Conferir/ajustar `__tests__/server.test.js`: ≥ 3 `it`, ≥ 2 endpoints (`/health`, `/api/orders`). *Verif.: `npm run test:ci` passa, tabela de coverage exibida.*
- [ ] **T5** 🤖 Verificar `.eslintrc.json` tem `semi`, `quotes`, `no-unused-vars` (R2) e `lint` no package.json. *Verif.: leitura do arquivo.*
- [ ] **T6** 🤖 Docker local: `docker build -t technova-api:local aula-08/`, `docker run -d`, `curl -f localhost:3000/health`, `docker rm -f`. *Verif.: 200 OK. (Se Docker indisponível no WSL, registro e valido só no CI.)*
- [ ] **T7** 🤖 Garantir `.gitignore` cobre `.env`, `node_modules`, `coverage`. *Verif.: `git ls-files | grep -i '\.env'` vazio.*
- [ ] **T8** 🤖 Commit `feat(aula-08): adiciona technova-api base`.

## Fase B — Workflow
- [ ] **T9** 🤖 Criar `.github/workflows/ci-aula08.yml` (D1–D9, D13): triggers, `paths`, `concurrency`, `permissions`, jobs `lint`/`test`(matrix 18+20)/`build`(+smoke)/`pr-comment`, cache npm, upload coverage. *Verif.: `actionlint` (ou `python -c yaml.safe_load`) sem erro.*
- [ ] **T10** 🤖 `aula-08/README.md` com badge + descrição; badge também no `README.md` da raiz. *Verif.: URL do badge aponta para `ci-aula08.yml`.*
- [ ] **T11** 🤖 Copiar `specs/` da disciplina para `specs/003-aula08-ci-github-actions/` no portfólio. 
- [ ] **T12** 🤖 Commit `ci(aula-08): workflow lint → test → build com badge`.

## Fase C — Secrets (⚠️ repo externo)
- [ ] **T13** 🤖⚠️ `gh secret set AWS_REGION` (= `us-east-1`) e `APP_ENV` (= `ci`) no portfólio. *Verif.: `gh secret list` mostra os nomes.*
- [ ] **T14** 🤖 Adicionar ao workflow o step que usa `${{ secrets.AWS_REGION }}` (checagem `[ -n ]` + um `echo` do valor fictício só para a evidência R5). Commit.

## Fase D — Primeiro run verde (⚠️ push)
- [ ] **T15** 🤖⚠️ Push da branch `feature/aula-08-ci-pipeline` (confirmo antes). *Verif.: `gh run watch`; os 3 jobs verdes, test com 2 combinações de matrix.*
- [ ] **T16** 🤖 Abrir PR da feature → `main` do portfólio (⚠️ confirmo). *Verif.: job `pr-comment` posta o comentário (B3).*
- [ ] **T17** 🤖 Segundo push (commit mínimo) para provar cache hit (B2); dois pushes seguidos para ver run cancelado (B4). *Verif.: "Cache restored" no log; run com status `cancelled`.*
- [ ] **T18** 🤖⚠️ Merge na `main` e push (conforme TF §1); aguardar run da `main` verde para o badge ficar "passing". *Verif.: `gh run list --branch main` = success.*

## Fase E — Run vermelho (R7)
- [ ] **T19** 🤖⚠️ Branch `test/pipeline-failing` com erro de lint intencional (aspas duplas / var não usada); push. *Verif.: job `lint` vermelho, `test` e `build` ignorados.*
- [ ] **T20** 🤖 Corrigir/descartar a branch e confirmar que a `main` segue verde.

## Fase F — Evidências (👤 prints)
Guia para tirar cada print (abra `https://github.com/gabrielreis354/unifaat-devops-portfolio`):
- [ ] **T21** 👤 `screenshot-pipeline-passing.png` — aba **Actions** → clique no run verde da `main` → print do grafo com `lint → test (18, 20) → build` todos ✅ e o nome do workflow visível.
- [ ] **T22** 👤 `screenshot-pipeline-failing.png` — **Actions** → run da branch `test/pipeline-failing` → print do grafo com ❌ no lint e os demais cancelados/ignorados.
- [ ] **T23** 👤 `screenshot-secrets-configured.png` — **Settings → Secrets and variables → Actions** → print da lista com `AWS_REGION` e `APP_ENV` (valores ocultos).
- [ ] **T24** 👤 Prints bônus (opcionais, mas citados no CA7): log do step de secret com `***`; "Cache restored"; comentário do bot no PR; run `cancelled` por concurrency; log do smoke test.
- [ ] **T25** 🤖 Salvar PNGs em `aula-08/screenshots/` (portfólio) e copiá-los para a pasta de entrega (decisão aprovada). *Dica de captura no WSL/Windows: `Win+Shift+S`; arquivos em `C:\Users\gabri\...` ficam acessíveis em `/mnt/c/...`.*

## Fase G — RESPOSTAS e Trabalho em Aula
- [ ] **T26** 🤖 `aula-08/RESPOSTAS.md` com as 4 questões do `TA.md` (conteúdo a validar por você, Q1). 
- [ ] **T27** 🤖 `trabalho-em-aula.md` no modelo da aula (pipeline em tabela + diagrama texto + 3 cenários × 4 perguntas). Você revisa, a entrega é individual.
- [ ] **T28** 🤖⚠️ Commit/push no portfólio (`docs(aula-08): RESPOSTAS e screenshots`).

## Fase H — Entrega na disciplina (⚠️ PR externo)
- [ ] **T29** 🤖 Em `/mnt/c/.../devops_20262`: atualizar `main`, criar branch `entregas/aula-08/6325149`, criar `entregas/aula-08/6325149/{entrega.md,trabalho-em-aula.md,screenshot-*.png}` (`entrega.md` no modelo do TF, checkboxes marcados, link do run e do repo).
- [ ] **T30** 🤖 Verificar `git diff --stat main` só em `entregas/aula-08/6325149/`; `git ls-files` sem `.env`.
- [ ] **T31** 🤖⚠️ Push no fork + PR `[Aula 08] RA: 6325149 - Gabriel Reis Cunha` (confirmo antes; a untracked `entregas/aula-07/6325149/` não entra).

## Fase I — Fechamento
- [ ] **T32** 🤖 Rodar checklist CA1–CA9 da SPEC com saída real e reportar falhas se houver.
- [ ] **T33** 🤖 Atualizar memória (checklist de evidências do TF da Aula 08) se algo novo for aprendido.

## Notas
- Sem recursos AWS nesta aula: nada a desligar (regra de custos não acionada).
- Prazo: 1 semana após a aula.
- Ordem crítica: T18 (main verde) antes de T21 (print); T19 depois de T18 para não sujar o badge.
