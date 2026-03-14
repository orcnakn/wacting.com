#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Wacting Production Deployment Script
# VDS üzerinde çalıştır: bash deploy.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

APP_DIR="/opt/wacting"
WEB_DIR="/var/www/wacting"
SERVER_DIR="${APP_DIR}/wacting-server"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║    WACTING — Production Deployment               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ─── 1. Pull Latest Code ─────────────────────────────────────────────────────
echo "▶ [1/7] Son kod çekiliyor..."
if [ -d "$APP_DIR" ]; then
  cd $APP_DIR
  git fetch origin main
  git reset --hard origin/main
  echo "   ✅ Kod güncellendi."
else
  echo "   ❌ $APP_DIR bulunamadı. Önce setup.sh çalıştırın."
  exit 1
fi

# ─── 2. Install Dependencies ─────────────────────────────────────────────────
echo "▶ [2/7] Bağımlılıklar yükleniyor..."
cd $SERVER_DIR
npm ci --omit=dev 2>/dev/null || npm install --omit=dev
echo "   ✅ npm bağımlılıkları yüklendi."

# ─── 3. Prisma — Generate Client + Push Schema ───────────────────────────────
echo "▶ [3/7] Prisma schema güncelleniyor..."
npx prisma generate
npx prisma db push --accept-data-loss 2>/dev/null || npx prisma db push
echo "   ✅ Veritabanı schema sync edildi."

# ─── 4. Build Server ─────────────────────────────────────────────────────────
echo "▶ [4/7] TypeScript build..."
npm run build
echo "   ✅ Server build tamamlandı: dist/"

# ─── 5. Deploy Flutter Web (if build exists) ──────────────────────────────────
echo "▶ [5/7] Flutter web dosyaları kontrol ediliyor..."
FLUTTER_BUILD="${APP_DIR}/wacting-server/dist/public/web"
if [ -d "$FLUTTER_BUILD" ] && [ -f "$FLUTTER_BUILD/index.html" ]; then
  mkdir -p $WEB_DIR
  cp -r $FLUTTER_BUILD/. $WEB_DIR/
  echo "   ✅ Flutter web dosyaları $WEB_DIR'e kopyalandı."
else
  # Alternatif: src/public/web
  SRC_WEB="${APP_DIR}/wacting-server/src/public/web"
  if [ -d "$SRC_WEB" ] && [ -f "$SRC_WEB/index.html" ]; then
    mkdir -p $WEB_DIR
    cp -r $SRC_WEB/. $WEB_DIR/
    echo "   ✅ Flutter web dosyaları (src) $WEB_DIR'e kopyalandı."
  else
    echo "   ⚠ Flutter web build bulunamadı — mevcut dosyalar korunuyor."
  fi
fi

# ─── 6. Seed Bot Users (if not already seeded) ───────────────────────────────
echo "▶ [6/7] Bot kullanıcılar kontrol ediliyor..."
# tsx gerekli — devDependency, production'da yüklenmeyebilir
if command -v npx &> /dev/null; then
  npm install --save-dev tsx@latest 2>/dev/null || true
  npx tsx src/scripts/seed_bots.ts 2>&1 || echo "   ⚠ Seed script atlandı (hata oluştu)."
else
  echo "   ⚠ tsx bulunamadı — seed script atlandı."
fi

# ─── 7. Restart Server ───────────────────────────────────────────────────────
echo "▶ [7/7] PM2 ile sunucu yeniden başlatılıyor..."
if command -v pm2 &> /dev/null; then
  pm2 describe wacting-server > /dev/null 2>&1 && {
    pm2 restart wacting-server
    echo "   ✅ wacting-server yeniden başlatıldı."
  } || {
    pm2 start dist/index.js --name wacting-server \
      --max-memory-restart 6G \
      --log /var/log/wacting-server.log
    pm2 save
    echo "   ✅ wacting-server başlatıldı."
  }
else
  echo "   ⚠ PM2 bulunamadı. Manuel başlatma gerekiyor: node dist/index.js"
fi

# ─── Nginx Reload ────────────────────────────────────────────────────────────
if command -v nginx &> /dev/null; then
  nginx -t 2>/dev/null && systemctl reload nginx
  echo "   ✅ Nginx yeniden yüklendi."
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  DEPLOYMENT TAMAMLANDI                                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  🌐 Web    : https://wacting.com                             ║"
echo "║  🔌 API    : https://api.wacting.com                         ║"
echo "║  📊 Admin  : https://api.wacting.com/admin/panel             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  pm2 status              → Sunucu durumu                     ║"
echo "║  pm2 logs wacting-server → Canlı loglar                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
