#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

require_root
require_confirm

EMAIL="${1:-}"
PASS="${2:-}"

if [ -z "$EMAIL" ] || [ -z "$PASS" ]; then
  echo "Usage: $0 user@$DOMAIN 'NewPassword123!'" >&2
  exit 1
fi

if ! grep -q "^$EMAIL:" "$DOVECOT_USERS"; then
  echo "ERROR: mailbox not found in $DOVECOT_USERS: $EMAIL" >&2
  exit 1
fi

HASH=$(openssl passwd -6 "$PASS")
sed -i "s#^$EMAIL:.*#$EMAIL:$HASH#" "$DOVECOT_USERS"
chown root:dovecot "$DOVECOT_USERS"
chmod 640 "$DOVECOT_USERS"
systemctl reload dovecot

echo "Password changed: $EMAIL"
