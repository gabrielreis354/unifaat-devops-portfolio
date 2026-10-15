# TASKS: TF + Trabalho em Aula da Aula 09

Legenda: 🤖 = eu executo · 👤 = Gabriel · ⚠️ = ação externa, confirmo antes.
Portfólio: `~/unifaat-devops-portfolio` · Disciplina: `/mnt/c/Users/gabri/unifaat_4sem/devops_20262`
Decisões fechadas: manter `ci-aula08.yml`; `push-image` separado de `build`; subir versão no `package.json`; **com** security scan separado (`security-scan.yml`, Parte 4 do lab — decisão do Gabriel); sem Bedrock.

## Fase A — Preparação e app (portfólio)
- [ ] **T1** 🤖 `git pull` e criar branch `feature/aula-09-registry-ai-review` a partir da `main`. *Verif.: `git branch --show-current`.*
- [ ] **T2** 🤖 Reescrever `aula-08/technova-api/Dockerfile` (multi-stage, labels OCI com `image.source` = repo do portfólio, usuário `technova`, HEALTHCHECK, `npm ci --omit=dev`); revisar `.dockerignore` (`.github`, `__tests__`, `.eslintrc*`, `coverage`). *Verif.: leitura dos arquivos.*
- [ ] **T3** 🤖 Verificar localmente: `npm ci && npm run lint && npm run test:ci`; `docker build`, `docker run -d`, `curl -f /health`, `docker inspect` (User, Healthcheck, Labels), `docker images` (tamanho), `docker rm -f`. *Verif.: saída real; se Docker indisponível, registro e valido no CI.*
- [ ] **T4** 🤖 Commit `feat(aula-09): dockerfile multi-stage para producao`.

## Fase B — Script de AI review (TDD)
- [ ] **T5** 🤖 Criar `.github/scripts/ai-review.test.js` (`node --test`): um caso por padrão (≥ 9), diff limpo, linha real do arquivo, auto-exclusão de `ai-review.js`/`*.md`/lockfile/`*.test.js`, `critical=true|false`. *Verif.: roda e **falha** (script ainda não existe).*
- [ ] **T6** 🤖 Implementar `.github/scripts/ai-review.js` (D8/D9): exporta `analyzeDiff`/`generateReport`; main só com `require.main === module`; escreve `/tmp/ai-review-result.md` e `critical=` em `GITHUB_OUTPUT`; `exit 0`. *Verif.: `node --test` verde, saída real colada.*
- [ ] **T7** 🤖 Rodar o script contra um diff real de exemplo (CRITICAL+WARNING+INFO) e conferir a tabela do relatório. *Verif.: markdown gerado.*
- [ ] **T8** 🤖 Commit `feat(aula-09): script de ai review com testes`.

## Fase C — Workflows
- [ ] **T9** 🤖 Evoluir `.github/workflows/ci-aula08.yml`: `name` → "CI — TechNova API"; `tags: ['v*.*.*']` no push; novo job `push-image` (`needs: build`, `if: github.event_name == 'push'`, `permissions: packages: write`, login/metadata/build-push, cache `gha`, `context: aula-08/technova-api`); `pr-comment` com título genérico. *Verif.: `actionlint`/`yaml.safe_load` sem erro.*
- [ ] **T10** 🤖 Criar `.github/workflows/ai-review.yml` (D7): testes do script → diff → análise → postar/atualizar comentário (`if: always()`) → gate `exit 1` se `critical=true`. *Verif.: `actionlint`/`yaml.safe_load`.*
- [ ] **T10b** 🤖 Criar `.github/workflows/security-scan.yml` (Parte 4 do lab, corrigido): secrets (AWS key, password, chave privada, JWT) e checagem do Dockerfile (`aula-08/technova-api/Dockerfile`: USER, `:latest`, HEALTHCHECK); o `git diff` exclui `.github/scripts`, `.github/workflows/security-scan.yml` e `*.md` (senão o workflow se auto-detecta); comentário **atualizado** com marker próprio `## 🔒 Security Scan Results`; falha (`exit 1`) se achar secret. *Verif.: `actionlint`/`yaml.safe_load`; rodar os greps localmente contra diff de exemplo.*
- [ ] **T11** 🤖 Commit `ci(aula-09): push da imagem para ghcr.io, ai review e security scan`.

## Fase D — Documentação (portfólio)
- [ ] **T12** 🤖 `aula-09/ia-cicd-analise.md`: tagging (e por quê), padrões verificados, lógica/prompt (incl. prompt Bedrock documentado e por que não usado), quando confiar vs revisar, limitações, lógica do gate, exclusões do script.
- [ ] **T13** 🤖 `aula-09/README.md` (como executar/testar, badge, link das imagens) e badge no `README.md` da raiz; copiar specs para `specs/004-aula09-registry-ai-review/`. *Verif.: URLs dos badges apontam para `ci-aula08.yml`/`ai-review.yml`.*
- [ ] **T14** 🤖 Commit `docs(aula-09): analise de ia no ci/cd e readme`.

## Fase E — PR da feature e merge (⚠️)
- [ ] **T15** 🤖⚠️ Push da branch + `gh pr create` (confirmo antes). *Verif.: `gh run watch`: lint/test/build verdes, `push-image` **skipped**, `ai-review` verde com comentário no PR.*
- [ ] **T16** 👤 Merge do PR na `main` pelo botão (ou `! gh pr merge N --repo gabrielreis354/unifaat-devops-portfolio --merge`).
- [ ] **T17** 🤖 Conferir run da `main`: `push-image` verde; `gh api` lista versões `sha-xxxxxxx` + `latest`. *Verif.: saída real.*
- [ ] **T18** 👤 Em *Package settings* do `technova-api` (ghcr.io): tornar **público** e confirmar vínculo ao repo (print `packages-tab.png` depois das tags semver).

## Fase F — Semver (⚠️)
- [ ] **T19** 🤖⚠️ Tag `v1.0.0` na `main` + push (confirmo antes). *Verif.: run da tag verde, versões `1.0.0`, `1.0`, `1`.*
- [ ] **T20** 🤖⚠️ Branch `fix/aula-09-bump-1.0.1` (`package.json` 1.0.1) → PR → Gabriel faz merge → tag `v1.0.1` + push. *Verif.: `1.0.1`, `1.0` aponta p/ o novo digest, `1` também.*
- [ ] **T21** 🤖 `docker pull` anônimo de `1.0.1`, `curl /health`, rollback para `1.0.0` (CA4). *Verif.: saída real.*

## Fase G — Demonstração do AI review e gate (⚠️)
- [ ] **T22** 🤖⚠️ Branch `test/ai-review-demo` com o `test-problems.js` do lab (Parte 6) em `aula-09/demo/` (fora do ESLint/CI da app), primeiro só com WARNING/INFO (`console.log`, `catch` vazio, TODO); push + PR de demonstração. *Verif.: comentário-tabela, check verde.*
- [ ] **T23** 🤖⚠️ 2º push adicionando CRITICAL (secret hardcoded, SQL injection, `eval()`). *Verif.: **mesmo** comentário atualizado (1 só), checks `AI Code Review` e `Security Scan` vermelhos.*
- [ ] **T24** 🤖 Opcional (checklist do lab): 3º push removendo o arquivo → comentário vira "✅ Nenhum problema". Depois fechar o PR sem merge e apagar a branch (confirmo antes); `main` segue verde.

## Fase H — Prints (👤)
Em `https://github.com/gabrielreis354/unifaat-devops-portfolio`:
- [ ] **T25** 👤 `packages-tab.png` — Packages → `technova-api`, com todas as tags visíveis.
- [ ] **T26** 👤 `ai-review-comment.png` — PR demo com a tabela de achados.
- [ ] **T27** 👤 `pipeline-passing.png` — Actions → run verde da `main` com lint → test → build → push-image.
- [ ] **T28** 👤 `quality-gate-block.png` — PR demo com `AI Code Review` ❌ (após T23, antes de fechar).
- [ ] **T29** 🤖 Salvar PNGs em `aula-09/screenshots/` no portfólio; commit/PR `docs(aula-09): screenshots` (⚠️ confirmo; Gabriel mescla).

## Fase I — Entrega na disciplina (⚠️)
- [ ] **T30** 🤖 `trabalho-em-aula.md` da aula 09 (tabela de tagging, 10 itens com severidade e "humano revisa?", discussão) — Gabriel revisa.
- [ ] **T31** 🤖 Branch `entregas/aula-09/6325149` a partir de `upstream/main`; `entregas/aula-09/6325149/{entrega.md, trabalho-em-aula.md}`; `entrega.md` no modelo do TF, checkboxes marcados, evidências embutidas (tags do Packages, trechos de log, tabela do comentário, links de runs/PRs/prints do portfólio). *Verif.: `git diff upstream/main...HEAD --stat` só em `entregas/aula-09/6325149/`; `git ls-files | grep -i '\.env'` vazio.*
- [ ] **T32** 🤖⚠️ Push no fork + PR `[Aula 09] RA: 6325149 - Gabriel Reis Cunha` (confirmo antes; `specs/` e `entregas/aula-07/.../node_modules` não entram).

## Fase J — Fechamento
- [ ] **T33** 🤖 Checklist CA1–CA12 da SPEC com saída real; reportar falhas.
- [ ] **T34** 🤖 Atualizar memória (lições da Aula 09: workflow evolui na aula 8, push de tag + paths, pacote ghcr.io público, auto-exclusão do script).

## Notas
- Sem AWS: nada a desligar (regra de custos não acionada).
- Ordem crítica: T17 antes de T19; T23 antes de T28; T25 só depois de T21.
- Prints de PR demo (T26/T28) precisam ser tirados **antes** de T24.
