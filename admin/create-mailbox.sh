#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

require_root
require_confirm

EMAIL="${1:-}"
PASS="${2:-}"

if [ -z "$EMAIL" ] || [ -z "$PASS" ]; then
  echo "Usage: $0 user@$DOMAIN 'Password123!'" >&2
  exit 1
fi

LOCAL="$(mail_localpart "$EMAIL")"
HASH=$(openssl passwd -6 "$PASS")

grep -v "^$EMAIL:" "$DOVECOT_USERS" > /tmp/dovecot_users.tmp || true
mv /tmp/dovecot_users.tmp "$DOVECOT_USERS"
echo "$EMAIL:$HASH" >> "$DOVECOT_USERS"

grep -v "^$EMAIL " "$POSTFIX_VMAILBOX" > /tmp/vmailbox.tmp || true
mv /tmp/vmailbox.tmp "$POSTFIX_VMAILBOX"
echo "$EMAIL $DOMAIN/$LOCAL/" >> "$POSTFIX_VMAILBOX"

mkdir -p "$VMAIL_BASE/$DOMAIN/$LOCAL/Maildir/"{cur,new,tmp}
chown -R vmail:vmail "$VMAIL_BASE/$DOMAIN/$LOCAL"

postmap "$POSTFIX_VMAILBOX"
chown root:dovecot "$DOVECOT_USERS"
chmod 640 "$DOVECOT_USERS"
systemctl reload postfix
systemctl reload dovecot

echo "Created: $EMAIL"
