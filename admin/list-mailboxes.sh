#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

require_root

echo "Mailboxes from $POSTFIX_VMAILBOX:"
cat "$POSTFIX_VMAILBOX" 2>/dev/null || true

echo
echo "Mailbox sizes:"
du -sh "$VMAIL_BASE/$DOMAIN"/* 2>/dev/null || true
