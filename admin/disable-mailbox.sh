#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

require_root
require_confirm

EMAIL="${1:-}"
if [ -z "$EMAIL" ]; then
  echo "Usage: $0 user@$DOMAIN" >&2
  exit 1
fi

backup_file "$DOVECOT_USERS"
backup_file "$POSTFIX_VMAILBOX"

grep -v "^$EMAIL:" "$DOVECOT_USERS" > /tmp/dovecot_users.tmp || true
mv /tmp/dovecot_users.tmp "$DOVECOT_USERS"

grep -v "^$EMAIL " "$POSTFIX_VMAILBOX" > /tmp/vmailbox.tmp || true
mv /tmp/vmailbox.tmp "$POSTFIX_VMAILBOX"

postmap "$POSTFIX_VMAILBOX"
chown root:dovecot "$DOVECOT_USERS"
chmod 640 "$DOVECOT_USERS"
systemctl reload postfix
systemctl reload dovecot

echo "Disabled login and delivery for: $EMAIL"
echo "Maildir was not deleted. Check: $VMAIL_BASE/$DOMAIN/${EMAIL%@*}"
