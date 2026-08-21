# Análise do Uso de IA — Aula 02 TF

> **Ferramenta de IA utilizada:** Claude Code (Claude Opus 4.8).
> _Obs.: o template original citava "Kiro"; substituído pela IA efetivamente usada. Ajustar se o professor exigir Kiro especificamente._

## Prompt Utilizado

```
Crie um docker-compose.yml para uma aplicação Node.js 20 com Express que usa
PostgreSQL 15 como banco de dados e Redis 7 como cache. A API roda na porta 3000.
O PostgreSQL precisa de volume nomeado para persistência. Todos os serviços devem
estar na mesma rede bridge customizada. Use variáveis de ambiente com interpolação
de arquivo .env. Adicione healthchecks, depends_on com condition, e restart policy
unless-stopped
```

## Output Original da IA

```yaml
# Aula 02 - TechNova | Stack: API Node.js 20 (Express) + PostgreSQL 15 + Redis 7
# Variaveis interpoladas a partir do arquivo .env (padrao ${VAR:-default}).
# Obs.: a chave "version" foi omitida de proposito (obsoleta no Docker Compose v2).

services:
  # ---------- API Node.js 20 / Express ----------
  api:
    build: .
    container_name: technova_api
    ports:
      - "${API_PORT:-3000}:3000"
    environment:
      PORT: 3000
      DB_HOST: postgres          # nome do servico = hostname na rede interna
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB:-technova}
      REDIS_HOST: redis
      REDIS_PORT: 6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    restart: unless-stopped
    networks:
      - app-network

  # ---------- PostgreSQL 15 ----------
  postgres:
    image: postgres:15-alpine
    container_name: technova_postgres
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-technova}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-technova123}
      POSTGRES_DB: ${POSTGRES_DB:-technova}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data   # volume nomeado = persistencia
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    restart: unless-stopped
    networks:
      - app-network

  # ---------- Redis 7 (cache) ----------
  redis:
    image: redis:7-alpine
    container_name: technova_redis
    ports:
      - "${REDIS_PORT:-6379}:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s
    restart: unless-stopped
    networks:
      - app-network

# ---------- Rede bridge customizada ----------
networks:
  app-network:
    driver: bridge

# ---------- Volume nomeado ----------
volumes:
  postgres_data:
```

_(Preservado no git como baseline no commit `7709c20`.)_

## Alterações que Fiz Manualmente

| O que mudei | Por quê |
|------------|---------|
| Troquei os valores fixos do bloco `environment` da api (`DB_HOST: postgres`, `DB_PORT: 5432`, `REDIS_HOST: redis`, `REDIS_PORT: 6379`, `PORT: 3000`) por interpolação `${...}` | Estavam **hardcoded**; a rubrica exige variáveis interpoladas do `.env` |
| Removi os defaults `${VAR:-default}` e passei a referenciar o `.env` diretamente | Deixa explícito que nada é hardcoded e força o uso do `.env` |
| Alinhei os nomes das variáveis ao `.env.example` do projeto (`API_PORT`/`POSTGRES_PORT` → `PORT`/`DB_PORT`/`REDIS_PORT`) | A IA inventou nomes que não batiam com o `.env.example` fornecido |
| Adicionei `DB_USER` e `DB_PASSWORD` (interpolados) ao ambiente da api | Estavam ausentes; necessários para a conexão futura com o banco |
| Removi a senha default `technova123` do fallback do postgres | Credencial hardcoded é má prática de segurança |

## O que a IA Acertou

- Estrutura correta dos 3 serviços (`api`, `postgres`, `redis`) e imagens certas: `postgres:15-alpine`, `redis:7-alpine`, Node 20 via Dockerfile local.
- Healthchecks bem escritos: `pg_isready` no Postgres, `redis-cli ping` no Redis e `wget` na rota `/health` da API.
- `depends_on` com `condition: service_healthy` correto — a API só sobe após os dependentes ficarem saudáveis.
- Detalhe avançado correto: `$$POSTGRES_USER` no healthcheck do Postgres (escapa a variável para ser resolvida **em runtime** dentro do container).
- Volume nomeado, rede bridge customizada, `restart: unless-stopped` nos 3 e comentários explicativos por seção.
- Omitiu a chave `version:` — boa prática no Docker Compose v2 (é obsoleta).

## O que a IA Errou ou Omitiu

- **Deixou vários valores hardcoded** no `environment` da api (`DB_HOST`, `DB_PORT`, `REDIS_HOST`, `REDIS_PORT`, `PORT`) em vez de interpolar do `.env` — contrariando o requisito "não hardcoded".
- **Nomes de variáveis inconsistentes** com o `.env.example` (usou `API_PORT`/`POSTGRES_PORT`, que não existiam no arquivo).
- Colocou uma **senha default no fallback** (`technova123`), o que é má prática para credenciais.

## Minha Avaliação

- **Tempo economizado usando IA:** ~15–20 min  ⟵ confirme/ajuste
- **Tempo gasto validando/corrigindo:** ~5 min  ⟵ confirme/ajuste
- **Nota para o output da IA (1-10):** 8  ⟵ confirme/ajuste
- **Usaria novamente para este tipo de tarefa?** Sim — o esqueleto veio correto e com boas práticas avançadas; exigiu apenas revisão para alinhar interpolação e nomes ao padrão do projeto. A validação humana (bater a rubrica) continua essencial.  ⟵ confirme/ajuste
