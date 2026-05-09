#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

certbot --nginx -d "$MAIL_HOST"

cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF2
ssl = required
ssl_cert = </etc/letsencrypt/live/$MAIL_HOST/fullchain.pem
ssl_key = </etc/letsencrypt/live/$MAIL_HOST/privkey.pem
EOF2

postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/$MAIL_HOST/fullchain.pem"
postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/$MAIL_HOST/privkey.pem"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtp_tls_security_level = may"

systemctl restart dovecot postfix

echo "Certificate check:"
openssl s_client -connect "$MAIL_HOST:993" -servername "$MAIL_HOST" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates || true
