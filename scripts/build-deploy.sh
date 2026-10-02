#!/usr/bin/env bash
# PS Club — DirectAdmin üçün backend + frontend zip hazırlayır (Linux/macOS).
# Windows ekvivalenti: scripts/build-deploy.ps1 (build-deploy.cmd ilə işə salınır).
#
# İstifadə:
#   scripts/build-deploy.sh
#
# Konfiqurasiya mühit dəyişənləri ilə override edilə bilər:
#   API_DOMAIN, WEB_DOMAIN  (default: psapi.sayt.cam / ps.sayt.cam)
set -euo pipefail

API_DOMAIN="${API_DOMAIN:-psapi.sayt.cam}"
WEB_DOMAIN="${WEB_DOMAIN:-ps.sayt.cam}"
API_BASE_URL="https://${API_DOMAIN}/api"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"
DIST_DIR="$ROOT_DIR/dist"
BACKEND_OUT="$DIST_DIR/backend-staging"
FRONTEND_OUT="$DIST_DIR/frontend-staging"
BACKEND_ZIP="$DIST_DIR/psapi-backend.zip"
FRONTEND_ZIP="$DIST_DIR/ps-frontend.zip"

PHP_BIN="${PHP_BIN:-php}"
COMPOSER_BIN="${COMPOSER_BIN:-composer}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

step() { printf '\n==> %s\n' "$1"; }

[ -f "$BACKEND_DIR/public/index.php" ] || { echo "Layihə kökü tapılmadı: $ROOT_DIR" >&2; exit 1; }

cat <<'BANNER'

╔══════════════════════════════════════╗
║   PS Club — Deploy zip builder       ║
╚══════════════════════════════════════╝
BANNER
echo "PHP:       $($PHP_BIN --version | head -1)"
echo "Composer:  $($COMPOSER_BIN --version 2>/dev/null | head -1)"
echo "Flutter:   $($FLUTTER_BIN --version 2>/dev/null | head -1)"
echo "Çıxış:     $DIST_DIR"

step 'dist qovluğu təmizlənir'
rm -rf "$DIST_DIR"
mkdir -p "$BACKEND_OUT" "$FRONTEND_OUT"

# ─── BACKEND ────────────────────────────────────────────────────────────────
step 'Backend: composer install (--no-dev)'
( cd "$BACKEND_DIR" && rm -rf vendor && "$COMPOSER_BIN" install --no-dev --optimize-autoloader --no-interaction )

step 'Backend: DirectAdmin strukturuna yığılır'
SITE_ROOT="$BACKEND_OUT/site-root"
PUBLIC_HTML="$BACKEND_OUT/public_html"
mkdir -p "$SITE_ROOT" "$PUBLIC_HTML"

# site-root: backend ağacı (vendor/public/scripts/.git/dist/.env xaric)
EXCLUDE_DIRS="vendor node_modules .git dist scripts public"
for entry in "$BACKEND_DIR"/* "$BACKEND_DIR"/.[!.]*; do
  [ -e "$entry" ] || continue
  name="$(basename "$entry")"
  if [ -d "$entry" ]; then
    skip=false
    for d in $EXCLUDE_DIRS; do [ "$name" = "$d" ] && skip=true; done
    $skip && continue
    cp -R "$entry" "$SITE_ROOT/$name"
  else
    case "$name" in .env|.env.local) continue;; esac
    cp "$entry" "$SITE_ROOT/$name"
  fi
done

cp -R "$BACKEND_DIR/vendor" "$SITE_ROOT/vendor"

# public_html: backend/public (setup skriptləri xaric)
cp -R "$BACKEND_DIR/public/." "$PUBLIC_HTML/"
for f in server-setup.php run-migrate.php reset-sales-data.php; do
  rm -f "$PUBLIC_HTML/$f"
done

# database: install.sql və setup.php zip-ə daxil deyil
rm -rf "$SITE_ROOT/database"
mkdir -p "$SITE_ROOT/database"
for entry in "$BACKEND_DIR"/database/*; do
  [ -e "$entry" ] || continue
  name="$(basename "$entry")"
  case "$name" in install.sql|setup.php) continue;; esac
  cp -R "$entry" "$SITE_ROOT/database/$name"
done

# storage placeholder qovluqları
for d in storage/business storage/products storage/receipts; do
  mkdir -p "$SITE_ROOT/$d"
  : > "$SITE_ROOT/$d/.gitkeep"
done

# public_html_FULL: tək qovluqda asan upload
PUBLIC_HTML_FULL="$BACKEND_OUT/public_html_FULL"
mkdir -p "$PUBLIC_HTML_FULL"
cp -R "$SITE_ROOT/." "$PUBLIC_HTML_FULL/"
cp -R "$PUBLIC_HTML/." "$PUBLIC_HTML_FULL/"

# setup/gizli faylları hər üç kökdən təmizlə
for root in "$PUBLIC_HTML" "$PUBLIC_HTML_FULL" "$SITE_ROOT"; do
  [ -d "$root" ] || continue
  find "$root" -type f \( -name server-setup.php -o -name run-migrate.php \
    -o -name reset-sales-data.php -o -name .env -o -name install.sql -o -name setup.php \) -delete
done

cat > "$BACKEND_OUT/OXU-BUNU.txt" <<EOF
PS Club API — DirectAdmin quraşdırma
====================================

1) DirectAdmin-də subdomain: $API_DOMAIN (SSL aktiv edin)
2) Yükləmə:
   A) TÖVSİYƏ (2 qovluq): site-root/ → domains/$API_DOMAIN/ ; public_html/ → public_html/
   B) ASAN (tək qovluq): public_html_FULL/ içindəkiləri → public_html/
3) Köhnə DirectAdmin index.html mütləq silinsin.
4) .env serverdə əvvəlcədən qalmalıdır (zip-ə daxil deyil). Nümunə: .env.example
5) DB migration: serverdəki .env ilə phinx və ya SQL patch. Ətraflı: docs/DEPLOY-MIGRATION-AZ.md
6) İcazələr: storage/ yazıla bilən (775).
7) PHP 8.2+ seçin.
8) Test: https://$API_DOMAIN/ping.php , sonra https://$API_DOMAIN/api/health

Demo: admin/admin , kassir/kassir (ilk girişdən sonra şifrələri dəyişin!)

storage/ qovluğu serverdə chmod 775 (və ya 755) olmalıdır.
EOF

step 'Backend: zip'
rm -f "$BACKEND_ZIP"
( cd "$BACKEND_OUT" && zip -rq "$BACKEND_ZIP" . )

# ─── FRONTEND ───────────────────────────────────────────────────────────────
step 'Frontend: flutter pub get'
( cd "$FRONTEND_DIR" && "$FLUTTER_BIN" pub get )

step "Frontend: flutter build web (API_URL=$API_BASE_URL)"
( cd "$FRONTEND_DIR" && "$FLUTTER_BIN" build web --release \
    --dart-define=API_URL="$API_BASE_URL" --pwa-strategy=none )

# Service worker tam söndür (köhnə cache qalmasın)
BOOTSTRAP="$FRONTEND_DIR/build/web/flutter_bootstrap.js"
if [ -f "$BOOTSTRAP" ]; then
  perl -0pi -e 's/,\s*serviceWorkerSettings:\s*\{[^}]*\}//g; s/serviceWorkerSettings:\s*\{[^}]*\},?\s*//g' "$BOOTSTRAP"
fi
rm -f "$FRONTEND_DIR/build/web/flutter_service_worker.js"

WEB_BUILD="$FRONTEND_DIR/build/web"
[ -f "$WEB_BUILD/index.html" ] || { echo "build/web tapılmadı" >&2; exit 1; }

step 'Frontend: public_html + .htaccess'
FE_PUBLIC="$FRONTEND_OUT/public_html"
mkdir -p "$FE_PUBLIC"
cp -R "$WEB_BUILD/." "$FE_PUBLIC/"
rm -f "$FE_PUBLIC/flutter_service_worker.js"

cat > "$FE_PUBLIC/.htaccess" <<'EOF'
RewriteEngine On
RewriteRule ^flutter_service_worker\.js$ - [G,L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.html [L]
<IfModule mod_headers.c>
  <FilesMatch "^(index\.html|flutter_bootstrap\.js|main\.dart\.js)$">
    Header set Cache-Control "no-cache, no-store, must-revalidate"
    Header set Pragma "no-cache"
    Header set Expires "0"
  </FilesMatch>
</IfModule>
EOF

cat > "$FRONTEND_OUT/OXU-BUNU.txt" <<EOF
PS Club Web — DirectAdmin quraşdırma
====================================

1) Domain: $WEB_DOMAIN (SSL aktiv)
2) public_html/ içindəkiləri → domains/$WEB_DOMAIN/public_html/
3) API əvvəlcə işləməlidir: https://$API_DOMAIN/api/health
4) Brauzerdə açın: https://$WEB_DOMAIN
5) İlk dəfə: F12 → Application → Service Workers → Unregister, Local Storage → Clear → Ctrl+Shift+R
EOF

step 'Frontend: zip'
rm -f "$FRONTEND_ZIP"
( cd "$FRONTEND_OUT" && zip -rq "$FRONTEND_ZIP" . )

# Staging sil (yalnız zip qalsın)
rm -rf "$BACKEND_OUT" "$FRONTEND_OUT"

printf '\n✓ Hazırdır!\n'
echo "  Backend zip:  $BACKEND_ZIP"
echo "  Frontend zip: $FRONTEND_ZIP"
echo "API test:  https://$API_DOMAIN/api/health"
echo "Web:       https://$WEB_DOMAIN"
echo "Demo: admin/admin, kassir/kassir"
