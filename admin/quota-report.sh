#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

require_root

echo "Mailbox disk usage:"
du -sh "$VMAIL_BASE/$DOMAIN"/* 2>/dev/null | sort -h || true

echo
echo "Message counts:"
for d in "$VMAIL_BASE/$DOMAIN"/*; do
  [ -d "$d" ] || continue
  echo "$(basename "$d"): $(find "$d/Maildir" -type f 2>/dev/null | grep -E '/new/|/cur/' | wc -l)"
done
