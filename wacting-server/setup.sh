#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Wacting VDS Setup Script — Ubuntu 20.04 LTS
# 4 CPU / 12 GB RAM / 300 GB SSD / OpenStack KVM
# Run as root: bash setup.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

DOMAIN="wacting.com"
API_DOMAIN="api.wacting.com"
DB_PASSWORD="$(openssl rand -hex 16)"
REPO="https://github.com/orcnakn/wacting.com.git"
APP_DIR="/opt/wacting"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   WACTING VDS SETUP — Ubuntu 20.04      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─── 1. System Update ────────────────────────────────────────────────────────
echo "▶ [1/9] Sistem güncelleniyor..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

# ─── 2. Essential Tools ──────────────────────────────────────────────────────
echo "▶ [2/9] Temel araçlar..."
apt-get install -y -qq \
  curl git wget gnupg2 ca-certificates lsb-release \
  software-properties-common openssl ufw

# ─── 3. Docker ───────────────────────────────────────────────────────────────
echo "▶ [3/9] Docker kuruluyor..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | bash
fi
systemctl enable docker
systemctl start docker

# ─── 4. Node.js 20 LTS ───────────────────────────────────────────────────────
echo "▶ [4/9] Node.js 20 LTS kuruluyor..."
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y -qq nodejs
fi
echo "   Node: $(node --version) | npm: $(npm --version)"

# ─── 5. PostgreSQL 14 + PostGIS ──────────────────────────────────────────────
echo "▶ [5/9] PostgreSQL 14 + PostGIS kuruluyor..."
# Ubuntu 20.04 için PostgreSQL 14 reposunu ekle
if ! command -v psql &> /dev/null; then
  wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
  echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
  apt-get update -qq
  apt-get install -y -qq postgresql-14 postgresql-14-postgis-3
fi
systemctl enable postgresql
systemctl start postgresql

# Create DB user & database
sudo -u postgres psql -c "CREATE USER wacting WITH PASSWORD '${DB_PASSWORD}';" 2>/dev/null || echo "   (User zaten var)"
sudo -u postgres psql -c "CREATE DATABASE wacting_db OWNER wacting;" 2>/dev/null || echo "   (DB zaten var)"
sudo -u postgres psql -d wacting_db -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true

# ─── 6. Nginx ────────────────────────────────────────────────────────────────
echo "▶ [6/9] Nginx kuruluyor..."
apt-get install -y -qq nginx certbot python3-certbot-nginx

cat > /etc/nginx/sites-available/wacting << 'NGINX'
# ── wacting.com — Flutter Web App ──────────────────────────────────────────
server {
    listen 80;
    server_name wacting.com www.wacting.com;

    root /var/www/wacting;
    index index.html;

    # Flutter web SPA: tüm routelar index.html'e yönlendirilir
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache";
    }

    # Flutter assets uzun süre cache'lenir (hash'li dosyalar)
    location ~* \.(js|css|wasm|png|jpg|svg|ico|json)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}

# ── api.wacting.com — Node.js Backend ──────────────────────────────────────
server {
    listen 80;
    server_name api.wacting.com;

    # CORS başlıkları
    add_header 'Access-Control-Allow-Origin' 'https://wacting.com' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type' always;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
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
        proxy_buffering off;
    }
}
NGINX

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/wacting /etc/nginx/sites-enabled/

mkdir -p /var/www/wacting
cat > /var/www/wacting/index.html << 'HTML'
<!DOCTYPE html>
<html><head><title>Wacting — Loading...</title>
<style>body{background:#0d0d0d;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;flex-direction:column;}
h1{font-size:2rem;letter-spacing:4px;margin-bottom:8px;}p{color:#666;}</style>
</head><body><h1>WACTING</h1><p>Deploying...</p></body></html>
HTML

nginx -t && systemctl restart nginx

# ─── 7. Clone & Build Server ─────────────────────────────────────────────────
echo "▶ [7/9] Wacting sunucusu klonlanıyor..."
if [ -d "$APP_DIR" ]; then
  cd $APP_DIR && git pull origin main
else
  git clone $REPO $APP_DIR
fi

cd $APP_DIR/wacting-server

cat > .env << EOF
DATABASE_URL="postgresql://wacting:${DB_PASSWORD}@localhost:5432/wacting_db"
NODE_ENV=production
PORT=3000
JWT_SECRET=$(openssl rand -hex 32)
CORS_ORIGIN=https://wacting.com
EOF

npm ci --omit=dev
npx prisma generate
npx prisma migrate deploy 2>/dev/null || echo "   (Migration henüz yok — ilk deploy'da normal)"
npx tsc 2>/dev/null || echo "   (TypeScript build atlandı — dist/ kullanılıyor)"

# ─── 8. PM2 ──────────────────────────────────────────────────────────────────
echo "▶ [8/9] PM2 ile sunucu başlatılıyor..."
npm install -g pm2

pm2 delete wacting-server 2>/dev/null || true

# dist/index.js yoksa doğrudan src çalıştır
if [ -f "dist/index.js" ]; then
  pm2 start dist/index.js --name wacting-server \
    --max-memory-restart 6G \
    --log /var/log/wacting-server.log
else
  pm2 start src/index.ts --name wacting-server \
    --interpreter ts-node \
    --max-memory-restart 6G \
    --log /var/log/wacting-server.log
fi

pm2 save
env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root | tail -1 | bash || true

# ─── 9. Firewall ─────────────────────────────────────────────────────────────
echo "▶ [9/9] Firewall ayarlanıyor..."
# Natro panelinde zaten bir firewall varsa UFW'yi devre dışı bırak
# Sadece Natro'nun panelinde 22/80/443 portlarını açtığınızdan emin olun
if ufw status | grep -q "Status: inactive"; then
  echo "   UFW devre dışı — Natro panel firewall kullanılıyor (OK)"
else
  ufw allow OpenSSH
  ufw allow 'Nginx Full'
  echo "   UFW aktif ve portlar açıldı"
fi

# ─── SSL ─────────────────────────────────────────────────────────────────────
echo ""
echo "⚡ SSL sertifikası almaya çalışılıyor..."
echo "   (DNS kayıtları henüz propagate olmadıysa hata verir — normal)"
certbot --nginx \
  -d $DOMAIN -d www.$DOMAIN -d $API_DOMAIN \
  --non-interactive --agree-tos \
  -m admin@wacting.com --redirect 2>/dev/null \
  && echo "✅ SSL başarıyla alındı!" \
  || echo "⚠  SSL sonra alınacak. DNS propogasyon sonrası: certbot --nginx"

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅  WACTING KURULUM TAMAMLANDI                           ║"
echo "╠════════════════════════════════════════════════════════════╣"
printf "║  DB Şifre : %-46s║\n" "${DB_PASSWORD}"
echo "║  API      : http://api.wacting.com                        ║"
echo "║  Web      : http://wacting.com                            ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  pm2 status          → Sunucu durumu                      ║"
echo "║  pm2 logs wacting-server → Canlı loglar                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Flutter build yüklemek için (yerel PC'nizden):"
echo "   bash build_web.sh"
echo "   scp -r wacting/build/web/* root@SUNUCU_IP:/var/www/wacting/"
echo ""
echo "🔐 DB şifresini kaydedin:"
echo "   ${DB_PASSWORD}"
echo ""
