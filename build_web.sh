#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Wacting Full Production Build Script
# Kullanım: bash build_web.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║    WACTING — Full Production Build               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# 1. Flutter web build
echo "▶ Flutter web build başlatılıyor..."
cd wacting
flutter build web \
  --release \
  --web-renderer canvaskit \
  --dart-define=PRODUCTION=true \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --tree-shake-icons
cd ..

echo "✅ Flutter build tamamlandı: wacting/build/web/"

# 2. Copy Flutter web build to server's public directory
echo "▶ Flutter web dosyaları sunucuya kopyalanıyor..."
mkdir -p wacting-server/src/public/web
cp -r wacting/build/web/. wacting-server/src/public/web/

echo "✅ Kopyalandı: wacting-server/src/public/web/"

# 3. Build Node.js server (tsc + copies public/)
echo "▶ Node.js server build başlatılıyor..."
cd wacting-server
npm run build
cd ..

echo "✅ Server build tamamlandı: wacting-server/dist/"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║    Build tamamlandı! Başlatmak için:             ║"
echo "║    cd wacting-server && node dist/index.js       ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
