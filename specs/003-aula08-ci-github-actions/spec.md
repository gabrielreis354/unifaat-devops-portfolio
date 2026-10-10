# SPEC: TF Aula 08 — Pipeline CI completo (GitHub Actions) para a TechNova API

## 1. Objetivo
Entregar o TF da Aula 08: um pipeline CI funcional (lint → test → build) com secrets e badge, publicado no `unifaat-devops-portfolio` (pasta `aula-08/`), e registrar a entrega via PR com `entrega.md` no repo da disciplina.

## 2. Contexto / Motivação (Why)
- O professor avalia automaticamente os workflows rodando na aba Actions do portfólio (repo público).
- Prazo: 1 semana após a aula. Peso: R1 25%, R3 20%, R4 15%, R2/R5/RESPOSTAS 10% cada, R6/R7 5% cada, bônus até +3 pts.
- O Trabalho em Aula (1 pt no semestre) pode ir no mesmo PR.

## 3. Escopo
### Dentro do escopo
- **Obrigatórios R1–R7** do `aula-08/TF.md`.
- `RESPOSTAS.md` (aparece nos critérios de avaliação, ver questão em aberto).
- `trabalho-em-aula.md` (individual), no mesmo PR.
- **Bônus B1–B5** (matrix Node 18/20, cache, comentário no PR, concurrency, smoke test) — o laboratório parte 2 já os ensina e o total é +3 pts.

### Fora do escopo (NÃO fazer)
- Qualquer recurso AWS (aula só usa GitHub Actions; secrets fictícios, ex.: `AWS_REGION=us-east-1`).
- Deploy real, environments com aprovação além do necessário ao TF.
- Alterar o conteúdo do repo da disciplina além de `entregas/aula-08/6325149/`.
- Push na `main` da disciplina / alterar a branch imutável da prova.

## 4. Requisitos funcionais
- RF1 (R1): `.github/workflows/ci-aula08.yml` com triggers `push` (main) e `pull_request`; jobs `lint`, `test`, `build` com nomes descritivos e `needs` (lint → test → build).
- RF2 (R2): `.eslintrc.json` com `semi`, `quotes`, `no-unused-vars`; script `lint`; ESLint sem erros.
- RF3 (R3): ≥ 3 testes Jest cobrindo ≥ 2 endpoints; script `test` com `--coverage`; todos passando.
- RF4 (R4): `Dockerfile` funcional; job `build` faz `docker build` com tag `${{ github.sha }}`.
- RF5 (R5): ≥ 1 secret cadastrado e referenciado via `${{ secrets.NAME }}`, com log mascarado visível.
- RF6 (R6): badge do workflow no README mostrando "passing".
- RF7 (R7): `screenshot-pipeline-passing.png`, `screenshot-pipeline-failing.png` (erro intencional, depois corrigido), `screenshot-secrets-configured.png`.
- RF8 (bônus): matrix Node 18/20; cache via `setup-node`; comentário automático em PR (GITHUB_TOKEN); `concurrency` com cancel-in-progress; smoke test do container com health check e remoção posterior.
- RF9 (entrega): PR no repo da disciplina, título `[Aula 08] RA: 6325149 - Gabriel Reis Cunha`, branch `entregas/aula-08/6325149`, pasta `entregas/aula-08/6325149/` com `entrega.md` (modelo do TF) + `trabalho-em-aula.md`.

## 5. Requisitos não-funcionais / Restrições
- Repositório `gabrielreis354/unifaat-devops-portfolio` público (já é).
- Nenhum `.env`/credencial real versionado; `.gitignore` cobre `.env`.
- Nada de `echo` de secrets nos workflows.
- Fluxo git: branch de feature no portfólio e Conventional Commits; confirmar com o Gabriel antes de cada push/PR (ação externa).
- Projeto base: copiar `technova-api/` (já na `main` da disciplina) para `aula-08/technova-api/`, conforme padrão do repo (commit `fix(aula-08)` de referência) — ver questão em aberto sobre o caminho.
- Entrega exata ao enunciado (regra de faculdade): sem extras além dos bônus listados.

## 6. Critérios de aceitação (verificáveis)
- [ ] CA1: `npm run lint`, `npm test` e `docker build` passam localmente antes do push.
- [ ] CA2: Run do workflow na aba Actions do portfólio com os 3 jobs verdes, na ordem lint → test → build.
- [ ] CA3: Cobertura impressa no log; ≥ 3 testes e ≥ 2 endpoints.
- [ ] CA4: Step que usa `${{ secrets.X }}` roda e o log mostra `***`.
- [ ] CA5: Badge no README renderiza "passing".
- [ ] CA6: Existe um run vermelho (erro intencional) no histórico e um run verde posterior.
- [ ] CA7: Cada bônus tem evidência (matrix com 2 versões; cache hit no 2º run; comentário no PR; concurrency cancelando run; smoke test no log).
- [ ] CA8: PR contém apenas arquivos de `entregas/aula-08/6325149/`; `entrega.md` com checkboxes marcados e link do run/prints.
- [ ] CA9: `git ls-files` do portfólio não contém `.env`.

## 7. Riscos e questões em aberto
- **Q1:** `RESPOSTAS.md` vale 10% mas nenhum documento diz o que responder. Pergunta ao professor, ou seriam as questões do `TA.md` (4 de múltipla escolha) / do trabalho em aula? Proposta: responder as 4 questões do TA com justificativa.
- **Q2:** Caminho do projeto: TF diz `aula-08/` na raiz do portfólio, e o commit `fix(aula-08)` do professor usa `aula-08/technova-api/`. O workflow tem que ficar em `.github/workflows/` na raiz do repo. Proposta: seguir `aula-08/technova-api/` com `working-directory`.
- **Q3:** Os screenshots são capturas manuais da UI do GitHub; eu preparo tudo, mas você precisa tirá-las (ou eu tento via browser, já que o MCP do Playwright está indisponível).
- **Q4:** Local do clone do portfólio (não existe localmente). Proposta: clonar em `~/unifaat-devops-portfolio`.
- **Q5:** Bônus: incluir todos (+3) ou só o núcleo? Proposta: todos, pois o custo é baixo.
- Risco: branch protection/“PR de si mesmo” para testar B3 exige abrir um PR dentro do portfólio (ação externa, confirmo antes).
- Risco: erro intencional (R7) deixa um run vermelho no histórico — esperado e exigido.
