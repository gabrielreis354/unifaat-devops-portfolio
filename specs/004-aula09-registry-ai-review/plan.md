# PLAN: TF + Trabalho em Aula da Aula 09

Decisões do Gabriel/professor: opção (a) — **evoluir a versão da Aula 08** (app e workflow), sem criar cópia em `aula-09/technova-api/`; sem Bedrock (script por regras + prompt documentado); screenshots só no portfólio; gate = check vermelho (sem branch protection).
Padrões adotados para as perguntas da SPEC ainda sem resposta (avisar se discordar): bônus baratos incluídos (cache de layers, badge, > 8 padrões); security scan separado **incluído** (decisão do Gabriel, coerência com o lab); pacote ghcr.io público (passo do Gabriel na UI).

## 1. Layout final no portfólio

```
.github/
├── workflows/
│   ├── ci-aula08.yml        # EVOLUÍDO: lint → test → build (smoke) → push (novo job) + pr-comment
│   ├── ai-review.yml        # NOVO: AI review em PR + quality gate
│   └── security-scan.yml    # NOVO: scan de secrets + Dockerfile (Parte 4 do lab)
└── scripts/
    ├── ai-review.js         # NOVO: regras + relatório (exporta funções; main só se executado direto)
    └── ai-review.test.js    # NOVO: testes com diffs de exemplo (node --test, sem dependências)
aula-08/technova-api/        # MESMA app; Dockerfile e package.json evoluídos
aula-09/
├── README.md                # como executar/testar + badges
├── ia-cicd-analise.md       # RF8
└── screenshots/             # packages-tab, ai-review-comment, pipeline-passing, quality-gate-block
specs/004-aula09-registry-ai-review/{spec,plan,tasks}.md
```
`aula-09/` guarda só documentação e prints (a "versão correta" do código vive em `aula-08/technova-api/` + `.github/`).

## 2. Decisões técnicas

| # | Decisão | Motivo / trade-off |
|---|---------|--------------------|
| D1 | **Manter o nome `ci-aula08.yml`** e evoluí-lo (job novo `push-image`); só o `name:` visível muda p/ "CI — TechNova API" | Renomear para `ci.yml` (nome do TF) quebraria o badge e o histórico já citados no `entrega.md` do PR #287. O `entrega.md` da 09 cita "pipeline = `ci-aula08.yml` (equivale ao `ci.yml` do TF)". Alternativa: `git mv` + atualizar badges. |
| D2 | Triggers: `push` em `main` **e** `tags: ['v*.*.*']`; `pull_request`; `workflow_dispatch`. `paths` ampliado só com `.github/workflows/ci-aula08.yml` (já existe) | Tags precisam disparar o CI; confirmar que filtro `paths` não bloqueia o push de tag (testar com `v1.0.0`) |
| D3 | Jobs: `lint` → `test` (matrix 18/20) → `build` (já faz build + smoke test, mantido como gate) → **`push-image`** (`needs: build`, `if: github.event_name == 'push'`) | O TF pede `build-and-push`; separar build/smoke de publish mantém o smoke da 08 e deixa o push condicional explícito (CA2: `skipped` em PR). Se o professor exigir um único job, fundir |
| D4 | `push-image`: `permissions: contents: read, packages: write` só nele; `docker/login-action@v3` (GITHUB_TOKEN), `metadata-action@v5` (tags `sha-`/`latest`/semver `{{version}}`,`{{major}}.{{minor}}`,`{{major}}`), `build-push-action@v5` com `context: aula-08/technova-api`, `cache-from/to: type=gha` | RF2/RF3 + bônus de cache. Imagem: `ghcr.io/${{ github.repository_owner }}/technova-api` |
| D5 | Dockerfile (em `aula-08/technova-api/`): multi-stage com labels OCI (`image.source` = repo do portfólio), usuário não-root nomeado `technova`, `HEALTHCHECK` (wget), `npm ci --omit=dev` | O `--only=production` do lab está deprecated. Confirmar que `.dockerignore` já exclui `__tests__`, `.eslintrc*`, `.github` (adicionar o que faltar) |
| D6 | Versão semver real: `package.json` → `1.0.1` no commit do patch, tags `v1.0.0` (merge da feature) e `v1.0.1` (commit seguinte) | Em vez do `echo "// patch fix" >> server.js` do lab; mudança legítima e rastreável |
| D7 | `ai-review.yml`: `pull_request` (opened/synchronize/reopened), `fetch-depth: 0`, `permissions: contents: read, pull-requests: write`; diff = `git diff origin/<base>...HEAD`; steps: rodar script → postar/atualizar comentário (`if: always()`) → **gate** (`exit 1` se `critical=true`) | Comentário sempre sai, mesmo com CRITICAL; o gate vem por último. Marker no comentário evita duplicar (busca `## 🤖 AI Code Review - TechNova`) |
| D8 | Script: parte do lab, com correções: (1) número de linha real do arquivo (parse do `@@ +N @@`), (2) regex sem `/g` ou `lastIndex` resetado, (3) **ignora** `.github/scripts/ai-review.js`, `*.md`, lockfiles e `*.test.js` (auto-bloqueio), (4) `process.exit(0)` e escreve `critical=true|false` em `GITHUB_OUTPUT` | Resolve riscos 2/3 da SPEC; documenta as exclusões no `ia-cicd-analise.md` |
| D9 | Padrões (≥ 9): CRITICAL — secret hardcoded, `eval()`, `exec` com template literal (command injection), SQL concatenado, chave AWS (`AKIA[0-9A-Z]{16}`); WARNING — `console.log/debug/info`, `catch` vazio, bind `0.0.0.0`, `http://` hardcoded; INFO — TODO/FIXME/HACK | RF6 + bônus (> 8) |
| D10 | Testes do script: `node --test .github/scripts/ai-review.test.js` com diffs de exemplo (um por padrão, um limpo, um que testa a exclusão do próprio script) | CA7 verificável localmente; também roda no `ai-review.yml` antes da análise (barato, protege o gate) |
| D11 | "IA": regras (pattern matching), conforme resposta do professor; `ia-cicd-analise.md` documenta o prompt que iria ao Bedrock (do lab, Opção B) e por que não foi usado (custo/credenciais efêmeras) | Sem AWS: nada a desligar |
| D12 | Evidências por PRs de demonstração no portfólio: **PR demo** `test/ai-review-demo`: 1º push só WARNING/INFO (check verde, print do comentário), 2º push adiciona CRITICAL (comentário *atualizado*, check vermelho, print do gate); depois fechado sem merge e branch apagada | CA5/CA6; mesma técnica da Aula 08 |
| D13 | Pacote: após o 1º push na `main`, Gabriel torna público em *Package settings* e confere o vínculo ao repo; eu valido com `docker pull` anônimo | Risco 1 |

## 3. Fluxo git / entrega

1. **Portfólio:** branch `feature/aula-09-registry-ai-review` (da `main`); commits convencionais por etapa (Dockerfile → CI → script+testes → ai-review.yml → docs). Push da branch e `gh pr create` (confirmo antes). O PR da feature já exercita o AI review (sem CRITICAL, pois o script se auto-exclui) e o CI sem push de imagem.
2. **Merge** pelo Gabriel (`gh pr merge` é bloqueado) → run da `main` publica `sha-` + `latest`.
3. **Tags** `v1.0.0` e, após o commit de patch (via PR curto), `v1.0.1` → semver no Packages. Push de tag = ação externa, confirmo antes.
4. **PR demo** (D12) → prints do comentário e do gate.
5. **Prints (Gabriel):** `packages-tab`, `ai-review-comment`, `pipeline-passing`, `quality-gate-block` → `aula-09/screenshots/` no portfólio.
6. **Disciplina:** branch `entregas/aula-09/6325149` a partir de `upstream/main`; `entrega.md` (modelo do TF, evidências embutidas: tags, trechos de log, tabela do comentário, links de runs/PRs, URLs dos prints no portfólio) + `trabalho-em-aula.md`. PR `[Aula 09] RA: 6325149 - Gabriel Reis Cunha`; confirmo antes. Só `entregas/aula-09/6325149/` no diff.

## 4. Verificação (antes de declarar pronto)

- Local: `npm ci && npm run lint && npm run test:ci` (app); `node --test .github/scripts/ai-review.test.js`; `docker build` + `run` + `curl /health` + `docker inspect` (usuário, healthcheck, labels); `actionlint`/`yaml.safe_load` nos workflows.
- Remoto: `gh run view` (jobs na ordem, `push-image` skipped em PR); `gh api /users/gabrielreis354/packages/container/technova-api/versions` com as tags; `docker pull` anônimo das tags `1.0.1`/`1.0.0` + rollback; comentário único atualizado e check vermelho no PR demo.
- Higiene: `git ls-files | grep -i '\.env'` vazio; diff do PR da disciplina só em `entregas/aula-09/6325149/`.

## 5. Dependências externas / bloqueios
- Gabriel: merge dos PRs, tornar pacote público, tirar os 4 prints (Playwright indisponível).
- Docker local no WSL (usado na Aula 08?) — senão valido só no CI.
- Data da aula 09 para cabeçalhos (assumo 14/10/2026 como data da entrega).

## 6. Pontos a confirmar neste checkpoint
- D1: manter `ci-aula08.yml` (proposto) ou renomear para `ci.yml`?
- D3: `push-image` separado de `build` (proposto) ou job único `build-and-push`?
- D6: subir a versão no `package.json` para o patch `v1.0.1` (proposto) em vez de editar o `server.js`?
- Security scan separado (bônus): incluir ou deixar de fora?

## 7. Atualização (2026-10-15)
- `push-image` separado de `build` (confirmado). Security scan **incluído** (D14): `security-scan.yml` do lab corrigido — caminho `aula-08/technova-api/Dockerfile`, exclusão de `.github/scripts`, do próprio workflow e de `*.md` no diff (auto-detecção), comentário atualizado em vez de duplicado, falha se achar secret.
- Demo (D12) usa o `test-problems.js` do lab em `aula-09/demo/` (não afeta lint/testes da app).
