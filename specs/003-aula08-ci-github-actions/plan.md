# PLAN: TF Aula 08 — CI com GitHub Actions

Decisões do Gabriel sobre a SPEC: Q1 vai validar com o professor; Q2 seguir o TF estritamente; Q3 vai reconfigurar o Playwright; Q4 clone em `~/unifaat-devops-portfolio` (já clonado, `main` limpa).

## 1. Layout final no portfólio (`gabrielreis354/unifaat-devops-portfolio`)

Segue o TF ao pé da letra: arquivos do projeto **diretamente em `aula-08/`** (sem subpasta `technova-api/`).

```
.github/workflows/ci-aula08.yml   # único local onde o GitHub executa workflows (raiz do repo)
aula-08/
├── server.js  package.json  package-lock.json
├── .eslintrc.json  .gitignore  .dockerignore  Dockerfile
├── __tests__/server.test.js      # + testes extras p/ >= 3 casos em >= 2 endpoints
├── README.md                     # contém o badge (R6) e descrição do CI
├── RESPOSTAS.md                  # Q1
└── screenshots/                  # 3 prints obrigatórios + prints dos bônus
specs/003-aula08-ci-github-actions/{spec,plan,tasks}.md   # convenção do portfólio (001, 002)
```

Origem dos arquivos: `technova-api/` da disciplina (já testada), copiada para `aula-08/`.
Badge: o TF diz "README do repositório" — o README da raiz do portfólio ganha o badge também (linha única), além do `aula-08/README.md`.

## 2. Decisões técnicas

| # | Decisão | Motivo / trade-off |
|---|---------|--------------------|
| D1 | Workflow na raiz `.github/workflows/ci-aula08.yml` com `defaults.run.working-directory: aula-08` | GitHub só lê a raiz. O TF cita `aula-08/.github/workflows` no `mkdir`, mas essa cópia nunca executaria; manter duas cópias viola DRY. **Se preferir a cópia inerte, avise.** |
| D2 | `paths: ['aula-08/**', '.github/workflows/ci-aula08.yml']` em push e PR | Não roda CI do portfólio em mudanças de outras aulas. Cuidado: precisa incluir o próprio workflow. |
| D3 | `push: branches: [main]`, `pull_request` (base main), `workflow_dispatch` | R1 |
| D4 | Jobs `lint` → `test` (needs lint) → `build` (needs [lint,test]); nomes descritivos | R1 |
| D5 | `setup-node@v4` com `cache: npm` e `cache-dependency-path: aula-08/package-lock.json`; `npm ci` | B2; lock já existe |
| D6 | `test`: matrix `['18','20']`, `npm run test:ci`; upload do `coverage/` só no Node 20 | B1, R3, `upload-artifact@v4` |
| D7 | `build`: `docker build -t technova-api:${{ github.sha }} aula-08/`; smoke test com `docker run -d`, loop de espera + `curl -f /health`, `docker rm -f` em `if: always()` | R4, B5; evita `sleep 3` frágil da referência |
| D8 | `concurrency: group: ci-${{ github.ref }}`, `cancel-in-progress: true` | B4 |
| D9 | Job `pr-comment` (só em `pull_request`), `permissions: pull-requests: write`, `github-script@v7` | B3. Em PR do próprio repo o token tem escrita |
| D10 | Secrets: cadastrar `AWS_REGION=us-east-1` (e `APP_ENV=ci`, fictícios) via `gh secret set`; step "Verificar secrets" no `test` ou job dedicado que usa `env: AWS_DEFAULT_REGION: ${{ secrets.AWS_REGION }}` e imprime só se está definido (`[ -n "$X" ]`) — nunca o valor | R5, CA4; a máscara `***` aparece quando o valor passa por `echo` do runner; para a evidência uso um `echo` do valor fictício **apenas** no demo (valor não sensível), documentado. |
| D11 | Erro intencional (R7): branch `test/pipeline-failing` com variável não usada/aspas duplas → lint vermelho, print, depois PR/branch descartada ou fix | CA6 |
| D12 | Testes: base tem health+orders; garantir >= 3 `it` em `/health` e `/api/orders` (+ POST/404 se necessário) | R3 |
| D13 | Segurança: `permissions: contents: read` no nível do workflow; apenas o `pr-comment` eleva | menor privilégio |

## 3. Fluxo git / entrega

1. **Portfólio:** branch `feature/aula-08-ci-pipeline` (padrão das aulas anteriores), commits convencionais por etapa, merge na `main` + push (confirmo antes de cada push, ação externa).
2. **Evidência de run:** disparar pelo push; para B3 abrir um PR de branch curta contra `main` do próprio portfólio; para B2 fazer 2º run para o cache hit; para B4 dois pushes seguidos.
3. **Disciplina:** a partir da `main` atualizada, branch `entregas/aula-08/6325149`, pasta `entregas/aula-08/6325149/` com `entrega.md` e `trabalho-em-aula.md`; copiar para ela os 3 screenshots obrigatórios (R7 diz "na pasta de entrega"; o `entrega.md` os referencia por link relativo). Isso conflita com "apenas `entrega.md`" do TF; **ponto a confirmar** (proposta: PNGs na pasta de entrega, pois R7 pede explicitamente).
4. **PR:** título `[Aula 08] RA: 6325149 - Gabriel Reis Cunha`, base `main` do upstream; confirmo com você antes de abrir.

## 4. Verificação (antes de declarar pronto)

- Local: `npm ci && npm run lint && npm run test:ci` e `docker build` + `docker run` + `curl /health` em `aula-08/`.
- Remoto: `gh run list/view` mostrando jobs verdes na ordem correta, matrix 18/20, cache hit no log do 2º run, log com `***`, comentário no PR, run cancelado por concurrency.
- Higiene: `git ls-files | grep -i '\.env'` vazio; `git diff --stat` do PR da disciplina só toca `entregas/aula-08/6325149/`.

## 5. Dependências externas / bloqueios
- Playwright MCP reconfigurado (Q3) para screenshots; sem ele, você tira os prints seguindo a lista no `tasks.md`.
- `gh` já autenticado como `gabrielreis354`; precisa de escopo para `gh secret set` (repo) — validar na T de secrets.
- Docker local no WSL para o teste local (senão a verificação do build fica só no CI).

## 6. Pontos a confirmar neste checkpoint
- D1: ok não duplicar o workflow em `aula-08/.github/workflows`?
- §3.3: PNGs na pasta de entrega junto do `entrega.md`?
- D10: ok exibir o valor de um secret **fictício** no log só na evidência R5 (o TF pede "log mascarado")?
