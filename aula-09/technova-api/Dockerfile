# ============================================
# Estágio 1: dependências de produção (builder)
# ============================================
FROM node:20-alpine AS builder

WORKDIR /app

# Copiar só os package files primeiro (aproveita o cache de layers)
COPY package*.json ./

# Instalar apenas dependências de produção (sem ESLint/Jest)
RUN npm ci --omit=dev && npm cache clean --force

# ============================================
# Estágio 2: runtime (imagem final)
# ============================================
FROM node:20-alpine AS runtime

# Metadata OCI: liga a imagem (ECR/ghcr.io) ao repositório de origem
LABEL org.opencontainers.image.source="https://github.com/gabrielreis354/unifaat-devops-portfolio"
LABEL org.opencontainers.image.description="TechNova API - Sistema de gestão de pedidos"

WORKDIR /app

# Usuário não-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S technova -u 1001 -G nodejs

# Dependências do builder + código da aplicação
COPY --from=builder /app/node_modules ./node_modules
COPY . .

USER technova

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
