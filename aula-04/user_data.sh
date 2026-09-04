#!/bin/bash
# user_data.sh - Provisiona a API TechNova (Node.js 18 + Express) na porta 3000.
set -euo pipefail
LOG=/var/log/technova-setup.log
exec > >(tee -a "$LOG") 2>&1

echo "[$(date)] Iniciando setup da TechNova API..."

# 1) Atualiza o sistema
yum update -y

# 2) Instala Node.js 18 (nodesource) e Git
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs git
echo "[$(date)] Node: $(node --version) | npm: $(npm --version)"

# 3) Cria a aplicacao
APP_DIR=/opt/technova-api
mkdir -p "$APP_DIR"
cd "$APP_DIR"

cat > package.json <<'JSON'
{
  "name": "technova-api",
  "version": "1.0.0",
  "description": "TechNova API - Aula 04",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.19.2" }
}
JSON

cat > server.js <<'JS'
const express = require('express');
const os = require('os');
const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'TechNova API - Rodando na AWS!',
    hostname: os.hostname(),
    uptime_s: Math.round(process.uptime()),
    aula: '04'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'technova-api' });
});

app.get('/orders', (req, res) => {
  res.json({
    orders: [
      { id: 1, product: 'Widget A', status: 'shipped' },
      { id: 2, product: 'Widget B', status: 'processing' }
    ]
  });
});

app.listen(PORT, '0.0.0.0', () => console.log('TechNova API na porta ' + PORT));
JS

# 4) Instala dependencias
npm install --omit=dev
echo "[$(date)] npm install concluido"

# 5) Inicia a API como servico systemd (resiliente a reboot)
cat > /etc/systemd/system/technova-api.service <<UNIT
[Unit]
Description=TechNova API
After=network.target

[Service]
ExecStart=/usr/bin/node ${APP_DIR}/server.js
WorkingDirectory=${APP_DIR}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now technova-api
echo "[$(date)] TechNova API iniciada na porta 3000."
