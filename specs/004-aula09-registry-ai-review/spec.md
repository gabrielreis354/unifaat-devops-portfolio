# SPEC: TF + Trabalho em Aula da Aula 09 — Docker Registry (ghcr.io) e AI Review com Quality Gate

## 1. Objetivo
Entregar o TF da Aula 09 (RA 6325149): pipeline CI `lint → test → build-and-push` publicando a imagem da `technova-api` no ghcr.io, workflow de AI Review em PRs com quality gate, `ia-cicd-analise.md` e 4 screenshots; mais o `trabalho-em-aula.md` da aula 09. Projeto no portfólio (`aula-09/`), entrega no fork da disciplina (`entregas/aula-09/6325149/`).

## 2. Contexto / Motivação (Why)
- Aula 09 está no `upstream/main` (README, TA, TF, TA, labs 1 e 2, trabalho-em-aula, relatório). Prazo do TF: 1 semana após a aula.
- O pipeline é pré-requisito dos módulos seguintes (deploy faz `pull` da imagem do ghcr.io).
- Reaproveita a `technova-api` da Aula 08 (`aula-08/technova-api/` já no portfólio, CI verde).
- Lição da Aula 08 (bot de avaliação lê **só o `entrega.md`**): embutir evidências no `entrega.md` e manter a estrutura de pastas esperada (`aula-09/technova-api/`).

## 3. Escopo
### Dentro do escopo
- **Portfólio** (`gabrielreis354/unifaat-devops-portfolio`), pasta `aula-09/`:
  - `aula-09/technova-api/` (cópia da API) com Dockerfile multi-stage de produção (labels OCI, usuário não-root, HEALTHCHECK) e `.dockerignore` enxuto.
  - Workflow CI `lint → test → build-and-push` (ghcr.io; tags `sha-`, `latest`, semver; push só em push para main/tags).
  - Workflow `ai-review.yml` + `.github/scripts/ai-review.js` (≥ 5 padrões; comentário em tabela por severidade; quality gate com `exit 1` em CRITICAL).
  - `ia-cicd-analise.md`, `README.md` (como executar/testar), `screenshots/` (4 obrigatórios).
  - Bônus de baixo custo: cache de layers (`cache-from/to: gha`), comentário atualizado (sem duplicar), badge, > 8 padrões. Security scan separado (lab parte 2, seção 4) como bônus se couber.
- **Disciplina** (fork `origin`, branch `entregas/aula-09/6325149`): `entrega.md` no modelo do TF (checkboxes + evidências embutidas) e `trabalho-em-aula.md` (tabela de tagging + 10 itens de AI review + discussão).
- Pré-quiz TA (4 questões) registrado como `RESPOSTAS`/memória, se o Gabriel quiser (não é entrega).

### Fora do escopo (NÃO fazer)
- AWS/Bedrock (Opção B do lab) — sem custo, sem recursos a desligar; só a Opção A (regras programáticas).
- Deploy da imagem em EC2/ECS (módulo 4).
- Mexer em aulas anteriores além do necessário (ex.: não alterar `ci-aula08.yml` salvo `paths`).
- Merge de PRs (o Gabriel faz); push na `main` das disciplinas.

## 4. Requisitos funcionais
- RF1: `ci-aula09.yml` (ou `ci.yml`): jobs `lint` → `test` (coverage) → `build-and-push` (`needs: [lint, test]`), `working-directory: aula-09/technova-api`.
- RF2: `build-and-push` faz login no ghcr.io com `GITHUB_TOKEN` (`permissions: packages: write`), usa `docker/metadata-action` e `build-push-action`; `if: github.event_name == 'push'` (não publica em PR).
- RF3: Tags: `sha-XXXXXXX` + `latest` (main) + semver `1.2.3`, `1.2`, `1` (tag git `v*.*.*`). Publicar `v1.0.0` e `v1.0.1` para evidenciar semver.
- RF4: Imagem visível na aba Packages, ligada ao repo (label `org.opencontainers.image.source`), pullável (`docker pull` + `/health`).
- RF5: `ai-review.yml` dispara em `pull_request` (`opened/synchronize/reopened`), coleta diff (`fetch-depth: 0`), roda `ai-review.js`, posta comentário-tabela categorizado (CRITICAL/WARNING/INFO) e **atualiza** o comentário existente em novos pushes.
- RF6: Script detecta ≥ 5 padrões (mín.: secret hardcoded, `eval()`, SQL injection, `console.log`, `catch` vazio) — meta: > 8.
- RF7: Quality gate: ≥ 1 CRITICAL → workflow falha (`exit 1`) **depois** de postar o comentário; só WARNING/INFO → passa. Lógica documentada no `ia-cicd-analise.md`.
- RF8: `ia-cicd-analise.md`: estratégia de tagging e por quê; padrões verificados; prompt/lógica; quando confiar na IA vs review humano; limitações (falsos positivos/negativos, contexto limitado).
- RF9: 4 screenshots: `packages-tab.png`, `ai-review-comment.png`, `pipeline-passing.png`, `quality-gate-block.png` (Gabriel tira; Playwright indisponível).
- RF10: `trabalho-em-aula.md` no modelo da aula (tags por evento: main/develop/v1.2.3/PR; tags proibidas em produção; 10 itens com severidade e "humano também revisa?"; discussão).

## 5. Requisitos não-funcionais / Restrições
- Segurança: `permissions` mínimas por job (só `build-and-push` com `packages: write`; só o job de review com `pull-requests: write`); nada de PAT; sem segredos no repo.
- Seguir o TF ao pé da letra; workflows na **raiz** do portfólio (`.github/…`), não em `aula-09/.github` (GitHub só executa a raiz) — mesma decisão da Aula 08.
- Custo zero: repo público, ghcr.io gratuito; sem AWS.
- `paths:` para que `ci-aula08.yml` e o CI da aula 09 não disparem um ao outro à toa.
- Commits convencionais com `Co-Authored-By`; branch de feature no portfólio; nunca commitar direto na `main` da disciplina; `specs/` e `entregas/aula-07/6325149/node_modules` não entram em commits.
- Entrega: PR `[Aula 09] RA: 6325149 - Gabriel Reis Cunha` com só `entregas/aula-09/6325149/…`.

## 6. Critérios de aceitação (verificáveis)
- [ ] CA1: Push/merge na `main` do portfólio roda lint → test → build-and-push verde (`gh run view`).
- [ ] CA2: Em PR, só lint e test rodam; `build-and-push` fica *skipped* (sem push de imagem).
- [ ] CA3: Packages lista `sha-xxxxxxx`, `latest`, `1.0.1`, `1.0`, `1` (e `1.0.0`); `gh api` / página confirma.
- [ ] CA4: `docker pull ghcr.io/gabrielreis354/technova-api:1.0.1` (anônimo) e `curl /health` = 200; rollback p/ `1.0.0` funciona.
- [ ] CA5: PR com problemas intencionais recebe comentário-tabela com achados CRITICAL/WARNING/INFO; novo push **atualiza** o mesmo comentário (1 comentário só).
- [ ] CA6: PR com CRITICAL → check `AI Code Review` vermelho; PR só com WARNING/INFO → verde.
- [ ] CA7: Script detecta ≥ 5 padrões (teste local do `.js` com diffs de exemplo, saída real).
- [ ] CA8: Dockerfile: imagem final sem devDependencies, `USER` não-root, HEALTHCHECK; `docker build` local ok.
- [ ] CA9: `ia-cicd-analise.md` cobre os 5 tópicos do RF8.
- [ ] CA10: 4 screenshots existentes e referenciados no `entrega.md`.
- [ ] CA11: `entrega.md` no modelo, com checkboxes marcados, link do repo e evidências embutidas (trechos de log, tags, tabela do comentário, links de runs/PRs).
- [ ] CA12: `git diff upstream/main...HEAD --stat` do PR só toca `entregas/aula-09/6325149/`; `git ls-files | grep -i '\.env'` vazio.

## 7. Riscos e questões em aberto
1. **Pacote ghcr.io nasce privado** → para pull anônimo e print, tornar público em *Package settings* (passo da UI do Gabriel) e conferir o vínculo ao repo (label `source`).
2. **Falso positivo do próprio script**: o diff de um PR que adiciona `ai-review.js` contém `eval(`, `password=`, etc. e se auto-bloquearia. Mitigar: o script ignora `.github/scripts/ai-review.js` e arquivos `.md`, ou o gate só analisa `aula-09/technova-api/` + Dockerfile/YAML. (Decidir no Plan.)
3. **Bugs do script do lab** a corrigir/documentar: número de linha é da linha do diff (não do arquivo); regex `/g` com `.test` (precisa reset de `lastIndex`); bloco markdown com ``` aninhado no enunciado; catch-all `TODO|FIXME` sem `\b`. Mantém o baseline do lab, mas ajustando o que quebrar.
4. **Gate "bloqueando o PR"**: o `exit 1` deixa o check vermelho; bloquear de fato o merge exige branch protection/required check (configuração do Gabriel na UI). Evidência = check vermelho no PR; decidir se ativa branch protection.
5. **PR de evidências**: precisa de PRs de demonstração no portfólio (um com CRITICAL, um limpo), como fizemos na Aula 08 — PR vermelho fechado sem merge.
6. **Nome do arquivo do workflow**: `ci-aula09.yml` (lab, coexiste com `ci-aula08.yml`) vs `ci.yml` (TF). Proposta: `ci-aula09.yml` e citar no `entrega.md`. Confirmar.
7. **Estrutura de entrega do TF vs. regra "apenas entrega.md"**: PNGs na pasta de entrega (como na 08, R7) ou só no portfólio? Proposta: só `entrega.md` + `trabalho-em-aula.md`, screenshots no portfólio com link absoluto (TF diz "apenas entrega.md"); se o bot não conseguir validar imagens, embutir descrição. Confirmar.
8. Conteúdo do `trabalho-em-aula.md` é proposta minha (não presenciei o grupo); Gabriel revisa.
9. Data da aula 09 (para cabeçalho e prazo) — assumo semana de 12–14/10/2026; confirmar.

## 8. Perguntas para o Gabriel (checkpoint)
- Q1: Nome do CI: `ci-aula09.yml` (proposto) ou `ci.yml`?
- Q2: Screenshots: só no portfólio (proposto, segue "apenas entrega.md") ou também na pasta de entrega como na Aula 08?
- Q3: Ativar branch protection (check obrigatório) no portfólio para o gate bloquear o merge de fato?
- Q4: Incluir o bônus do security scan separado + cache de layers + badge? (proposto: sim, são baratos)
- Q5: Tornar o pacote público no ghcr.io (necessário para pull anônimo) — ok?

## 9. Respostas do professor (2026-10-14)
1. Workflows na **raiz** do repo, "mas coloca ele na aula 8, pois vamos evoluir e a cada aula precisa ter a versão correta dele" → **interpretação pendente de confirmação** (ver abaixo).
2. Só `entrega.md` no PR; prints ficam no portfólio. → **Q2 resolvida** (screenshots só no portfólio; RF9/CA10 ajustados: link no entrega.md).
3. Basta o **check vermelho**; branch protection exigiria plano pago. → **Q3 resolvida** (sem branch protection; risco 4 encerrado; CA6 = check vermelho).
4. "Vocês podem usar o Learner Lab para usar o Bedrock." → **pendente**: Bedrock cobra por token (fora do free-tier) e o CI precisaria de credenciais temporárias do Learner Lab como secrets (expiram a cada sessão). Opção permanece **opcional**; decisão do Gabriel.
