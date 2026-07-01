#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/host-keys.nix"

echo "[*] update-keys.sh — scanning SSH public keys from system users"
echo "    output: $OUT"
echo ""

echo "[" > "$OUT"
count=0
for dir in /home/*/.ssh /root/.ssh; do
  [ -d "$dir" ] || continue
  user="$(echo "$dir" | cut -d/ -f3)"
  found=0
  for f in "$dir"/id_*.pub; do
    [ -f "$f" ] || continue
    key="$(cat "$f")"
    fingerprint="$(ssh-keygen -lf "$f" 2>/dev/null | awk '{print $2}')"
    echo "  + $user ${fingerprint:-$(echo "$key" | cut -d' ' -f2)}"
    echo "  \"$key\"" >> "$OUT"
    count=$((count + 1))
    found=1
  done
  [ "$found" = 0 ] && echo "  - $user (no .pub files found)"
done
echo "]" >> "$OUT"

echo ""
if [ "$count" -gt 0 ]; then
  echo "[+] wrote $count key(s) to $OUT"
else
  echo "[-] no SSH public keys found anywhere"
fi
