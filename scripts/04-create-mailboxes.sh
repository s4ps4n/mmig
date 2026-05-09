#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

if [ ! -f "$MAILBOXES_CSV" ]; then
  echo "ERROR: CSV not found: $MAILBOXES_CSV" >&2
  exit 1
fi

header="$(head -n 1 "$MAILBOXES_CSV" | tr -d '\r')"
if [ "$header" != "email,app_password,new_password,maxage" ]; then
  echo "ERROR: wrong CSV header" >&2
  echo "Expected: email,app_password,new_password,maxage" >&2
  echo "Found: $header" >&2
  exit 1
fi

mkdir -p "$VMAIL_BASE/$DOMAIN"
chown -R vmail:vmail "$VMAIL_BASE/$DOMAIN"

tail -n +2 "$MAILBOXES_CSV" | while IFS=',' read -r email app_password new_password maxage; do
  email=$(echo "$email" | tr -d '\r' | xargs)
  new_password=$(echo "$new_password" | tr -d '\r')
  [ -z "$email" ] && continue
  localpart="$(mail_localpart "$email")"

  echo "Creating mailbox: $email"
  HASH=$(openssl passwd -6 "$new_password")

  grep -v "^$email:" "$DOVECOT_USERS" > /tmp/dovecot_users.tmp || true
  mv /tmp/dovecot_users.tmp "$DOVECOT_USERS"
  echo "$email:$HASH" >> "$DOVECOT_USERS"

  grep -v "^$email " "$POSTFIX_VMAILBOX" > /tmp/vmailbox.tmp || true
  mv /tmp/vmailbox.tmp "$POSTFIX_VMAILBOX"
  echo "$email $DOMAIN/$localpart/" >> "$POSTFIX_VMAILBOX"

  mkdir -p "$VMAIL_BASE/$DOMAIN/$localpart/Maildir/"{cur,new,tmp}
  chown -R vmail:vmail "$VMAIL_BASE/$DOMAIN/$localpart"
done

postmap "$POSTFIX_VMAILBOX"
chown root:dovecot "$DOVECOT_USERS"
chmod 640 "$DOVECOT_USERS"

systemctl reload dovecot
systemctl reload postfix

echo "DONE: mailboxes created"
