# Respostas — Aula 08: GitHub Actions e CI Pipelines

**Aluno:** Gabriel Reis Cunha
**RA:** 6325149

## Questão 1 — O que dispara a execução de um workflow?

**Resposta: b)** Eventos configurados no campo `on:` do YAML (push, pull_request, workflow_dispatch, schedule etc.).

As demais estão erradas: o GitHub não executa workflows por tempo fixo sem um `schedule` configurado (a), não exige clique manual salvo no `workflow_dispatch` (c) e não depende de um administrador fazer deploy (d).

## Questão 2 — Qual a função de `needs`?

**Resposta: c)** Cria dependência entre jobs: o job só executa se os jobs listados em `needs` terminarem com sucesso.

No nosso pipeline, `test` usa `needs: lint` e `build` usa `needs: [lint, test]`, então um erro de lint impede testes e build. Secrets (a), runners (b) e retry (d) são configurados por outras chaves (`secrets`/`env`, `runs-on`, políticas de re-run).

## Questão 3 — Onde guardar credenciais AWS?

**Resposta: c)** Em GitHub Secrets (Settings → Secrets and variables → Actions), referenciadas com `${{ secrets.NAME }}`.

Um `.env` commitado (a) fica no histórico do Git mesmo se for apagado depois, e o GitHub só mascara secrets cadastrados, não arquivos do repositório. Variáveis no `runs-on` (b) e um campo `credentials:` no YAML (d) deixariam o valor em texto puro no código.

## Questão 4 — Propósito de environments com approval gates

**Resposta: b)** Garantir que deploys para ambientes sensíveis (como produção) exijam aprovação humana antes de executar.

Os environments também permitem restringir branches de deploy, aplicar um wait timer e ter secrets visíveis apenas àquele ambiente. Não servem para acelerar jobs (a), expor secrets nos logs (c) nem copiar o repositório (d).
