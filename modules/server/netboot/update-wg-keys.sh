#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/wg-keys.nix"
KEYDIR="/etc/wireguard/netboot"

echo "[*] update-wg-keys.sh — generating WireGuard keys for netboot"

mkdir -p "$KEYDIR"

if [ ! -f "$KEYDIR/host.priv" ]; then
  wg genkey | tee "$KEYDIR/host.priv" | wg pubkey > "$KEYDIR/host.pub"
  chmod 600 "$KEYDIR/host.priv"
  echo "  + generated host keys"
else
  echo "  = host keys already exist"
fi

if [ ! -f "$KEYDIR/client.priv" ]; then
  wg genkey | tee "$KEYDIR/client.priv" | wg pubkey > "$KEYDIR/client.pub"
  chmod 600 "$KEYDIR/client.priv"
  echo "  + generated client keys"
else
  echo "  = client keys already exist"
fi

hostPub=$(cat "$KEYDIR/host.pub")
clientPub=$(cat "$KEYDIR/client.pub")

# Copy client private key to flake source (.gitignore'd, force-added to git)
cp "$KEYDIR/client.priv" "$DIR/client-priv-key"
echo "  + copied client private key to $DIR/client-priv-key"

git -C "$DIR" add --force client-priv-key
echo "  + force-added client-priv-key to git index"

cat > "$OUT" <<EOF
{
  hostPublicKey = "$hostPub";
  clientPublicKey = "$clientPub";
  hostPrivateKeyFile = "$KEYDIR/host.priv";
}
EOF

echo "[+] wrote $OUT"

# Force-add wg-keys.nix to git so it's in the flake source
if git -C "$DIR" ls-files --error-unmatch wg-keys.nix &>/dev/null; then
  echo "  = wg-keys.nix already tracked"
else
  git -C "$DIR" add --force wg-keys.nix
  echo "  + force-added wg-keys.nix to git"
fi
