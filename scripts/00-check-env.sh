#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root

echo "DOMAIN=$DOMAIN"
echo "MAIL_HOST=$MAIL_HOST"
echo "SERVER_IP=$SERVER_IP"
echo "OLD_IMAP_HOST=$OLD_IMAP_HOST"
echo "MAILBOXES_CSV=$MAILBOXES_CSV"

for cmd in postconf dovecot openssl dig ss awk sed grep; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "WARN: command not found: $cmd"
  fi
done

if [ -f "$MAILBOXES_CSV" ]; then
  header="$(head -n 1 "$MAILBOXES_CSV" | tr -d '\r')"
  expected="email,app_password,new_password,maxage"
  if [ "$header" != "$expected" ]; then
    echo "ERROR: wrong CSV header"
    echo "Expected: $expected"
    echo "Found: $header"
    exit 1
  fi
  echo "CSV header OK"
else
  echo "WARN: CSV not found: $MAILBOXES_CSV"
fi

echo "Listening ports:"
ss -tulpn | egrep ':25|:465|:587|:993|:143|:80|:443|:8887|:8888' || true

echo "DNS snapshot:"
dig +short "$MAIL_HOST" A || true
dig +short "$DOMAIN" MX || true
