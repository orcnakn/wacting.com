#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Wacting VDS Setup Script
# Ubuntu 22.04 LTS — 4 CPU / 12 GB RAM / OpenStack KVM
# Run as root: bash setup.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e  # Exit on any error

DOMAIN="wacting.com"
API_DOMAIN="api.wacting.com"
DB_PASSWORD="CHANGE_ME_$(openssl rand -hex 12)"
REPO="https://github.com/orcnakn/wacting.com.git"
APP_DIR="/opt/wacting"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║      WACTING VDS SETUP — BAŞLIYOR        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─── 1. System Update ────────────────────────────────────────────────────────
echo "▶ [1/9] Sistem güncelleniyor..."
apt-get update -qq && apt-get upgrade -y -qq

# ─── 2. Essential Tools ──────────────────────────────────────────────────────
echo "▶ [2/9] Temel araçlar kuruluyor..."
apt-get install -y -qq curl git nginx certbot python3-certbot-nginx ufw openssl

# ─── 3. Docker ───────────────────────────────────────────────────────────────
echo "▶ [3/9] Docker kuruluyor..."
curl -fsSL https://get.docker.com | bash
systemctl enable docker && systemctl start docker

# ─── 4. Node.js 20 LTS ───────────────────────────────────────────────────────
echo "▶ [4/9] Node.js 20 LTS kuruluyor..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y -qq nodejs

# ─── 5. PostgreSQL ───────────────────────────────────────────────────────────
echo "▶ [5/9] PostgreSQL 15 + PostGIS kuruluyor..."
apt-get install -y -qq postgresql-15 postgresql-15-postgis-3
systemctl enable postgresql && systemctl start postgresql

# Create DB and user
sudo -u postgres psql -c "CREATE USER wacting WITH PASSWORD '${DB_PASSWORD}';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE wacting_db OWNER wacting;" 2>/dev/null || true
sudo -u postgres psql -d wacting_db -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true

# ─── 6. Clone & Build Server ─────────────────────────────────────────────────
echo "▶ [6/9] Wacting sunucusu klonlanıyor ve kuruluyor..."
mkdir -p $APP_DIR
git clone $REPO $APP_DIR 2>/dev/null || (cd $APP_DIR && git pull)

cd $APP_DIR/wacting-server

# Write .env file
cat > .env << EOF
DATABASE_URL="postgresql://wacting:${DB_PASSWORD}@localhost:5432/wacting_db"
NODE_ENV=production
PORT=3000
JWT_SECRET=$(openssl rand -hex 32)
EOF

npm install --production
npx prisma generate
npx prisma migrate deploy || echo "⚠ Migration skipped (no migrations yet)"
npm run build 2>/dev/null || npx tsc 2>/dev/null || echo "⚠ Build skipped — using src directly"

# ─── 7. PM2 (Process Manager) ────────────────────────────────────────────────
echo "▶ [7/9] PM2 ile sunucu başlatılıyor..."
npm install -g pm2
pm2 start dist/index.js --name wacting-server --max-memory-restart 4G 2>/dev/null || \
pm2 start src/index.ts --name wacting-server --interpreter ts-node 2>/dev/null || \
pm2 start src/index.js --name wacting-server
pm2 startup systemd -u root --hp /root
pm2 save

# ─── 8. Nginx ────────────────────────────────────────────────────────────────
echo "▶ [8/9] Nginx yapılandırılıyor..."
cat > /etc/nginx/sites-available/wacting << 'NGINX'
server {
    listen 80;
    server_name wacting.com www.wacting.com;

    # Flutter Web (static files will be served from here)
    root /var/www/wacting;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}

server {
    listen 80;
    server_name api.wacting.com;

    # Node.js API
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket — Brownian Physics Engine
    location /socket.io/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/wacting /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
mkdir -p /var/www/wacting
echo "<h1>Wacting — Coming soon</h1>" > /var/www/wacting/index.html
nginx -t && systemctl restart nginx

# ─── 9. SSL (Let's Encrypt) ──────────────────────────────────────────────────
echo "▶ [9/9] SSL sertifikası alınıyor..."
certbot --nginx \
  -d $DOMAIN \
  -d www.$DOMAIN \
  -d $API_DOMAIN \
  --non-interactive \
  --agree-tos \
  -m admin@wacting.com \
  --redirect || echo "⚠ SSL henüz alınamadı — DNS kayıtları propagate olduktan sonra tekrar çalıştırın: certbot --nginx"

# ─── Firewall ────────────────────────────────────────────────────────────────
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  WACTING SUNUCU KURULUMU TAMAMLANDI                     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  API    : https://api.wacting.com                           ║"
echo "║  WEB    : https://wacting.com                               ║"
echo "║  PM2    : pm2 status                                        ║"
echo "║  Logs   : pm2 logs wacting-server                           ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  DB Şifresi (kaydet!): ${DB_PASSWORD}    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Flutter build yüklemek için:"
echo "   scp -r build/web/* root@<SUNUCU_IP>:/var/www/wacting/"
echo ""
