#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Flutter Web Production Build Script
# Kullanım: .\build_web.sh
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║    WACTING — Flutter Web Production Build        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Production build (PRODUCTION=true flag ile AppConfig.isProduction = true olur)
flutter build web \
  --release \
  --web-renderer canvaskit \
  --dart-define=PRODUCTION=true \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --tree-shake-icons

echo ""
echo "✅ Build tamamlandı: build/web/"
echo ""
echo "📤 Sunucuya yüklemek için:"
echo "   scp -r build/web/* root@<SUNUCU_IP>:/var/www/wacting/"
echo ""
echo "Örnek:"
echo "   scp -r build/web/* root@85.123.45.67:/var/www/wacting/"
