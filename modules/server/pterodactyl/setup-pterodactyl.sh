#!/usr/bin/env bash
set -euo pipefail

# Pterodactyl Panel — one-time setup script
# Run AFTER nixos-rebuild switch with services.pterodactyl.enable = true
#
# Usage: sudo ./setup-pterodactyl.sh
# (root is needed to write to /srv/pterodactyl and run systemctl)

DATA_DIR="/srv/pterodactyl"
PANEL_VERSION="v1.14.0"
REPO="https://github.com/pterodactyl/panel"

echo "==> Downloading panel release ${PANEL_VERSION}..."
curl -fsSL -o /tmp/panel.tar.gz \
  "${REPO}/releases/download/${PANEL_VERSION}/panel.tar.gz"

echo "==> Extracting to ${DATA_DIR}..."
rm -rf "${DATA_DIR:?}"/*
tar -xzf /tmp/panel.tar.gz -C "${DATA_DIR}"
rm /tmp/panel.tar.gz

echo "==> Setting ownership so composer/artisan run as pterodactyl..."
chown -R pterodactyl:pterodactyl "${DATA_DIR}"
chmod 750 "${DATA_DIR}"
chmod 755 "${DATA_DIR}/public"

echo "==> Installing Composer dependencies..."
sudo -u pterodactyl nix-shell -p php83 php83Packages.composer --run \
  "cd ${DATA_DIR} && composer install --no-dev --optimize-autoloader --no-interaction"

echo "==> Generating app key if missing..."
if ! grep -q "^APP_KEY=" "${DATA_DIR}/.env" 2>/dev/null || \
   grep -q "APP_KEY=base64:CHANGE_ME" "${DATA_DIR}/.env" 2>/dev/null; then
  sudo -u pterodactyl nix-shell -p php83 --run "cd ${DATA_DIR} && php artisan key:generate --force"
fi

echo "==> Running database migrations..."
sudo -u pterodactyl nix-shell -p php83 --run "cd ${DATA_DIR} && php artisan migrate --seed --force"

echo "==> Fixing permissions..."
chmod -R 755 "${DATA_DIR}/storage" "${DATA_DIR}/bootstrap/cache"

echo ""
echo "============================================"
echo " Panel deployed! Create an admin user:"
echo "  sudo nix-shell -p php83 --run 'php ${DATA_DIR}/artisan p:user:make'"
echo ""
echo " Then configure Wings from the panel and"
echo " place the config at /etc/pterodactyl/config.yml"
echo "============================================"
