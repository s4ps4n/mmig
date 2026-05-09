#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root

echo "A record:"
dig +short "$MAIL_HOST" A || true

echo "MX:"
dig +short "$DOMAIN" MX || true

echo "SPF/TXT:"
dig +short "$DOMAIN" TXT || true

echo "DKIM:"
dig +short "${DKIM_SELECTOR}._domainkey.$DOMAIN" TXT || true

echo "DMARC:"
dig +short "_dmarc.$DOMAIN" TXT || true

echo "PTR:"
dig -x "$SERVER_IP" +short || true

echo "Services:"
systemctl is-active postfix || true
systemctl is-active dovecot || true
systemctl is-active opendkim || true

echo "Ports:"
ss -tulpn | egrep ':25|:465|:587|:993|:143|:80|:443' || true

echo "TLS checks:"
openssl s_client -connect "$MAIL_HOST:993" -servername "$MAIL_HOST" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates || true
openssl s_client -connect "$MAIL_HOST:465" -servername "$MAIL_HOST" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates || true
openssl s_client -starttls smtp -connect "$MAIL_HOST:587" -servername "$MAIL_HOST" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates || true

echo "Postfix queue:"
postqueue -p || true
