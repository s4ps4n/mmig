#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

backup_file /etc/postfix/main.cf
backup_file /etc/postfix/master.cf
backup_file "$POSTFIX_VDOMAINS"
backup_file "$POSTFIX_VMAILBOX"

mkdir -p "$(dirname "$POSTFIX_VDOMAINS")"
cat > "$POSTFIX_VDOMAINS" <<EOF2
$DOMAIN OK
EOF2

touch "$POSTFIX_VMAILBOX"
postmap "$POSTFIX_VDOMAINS"
postmap "$POSTFIX_VMAILBOX"

postconf -e "myhostname = $MAIL_HOST"
postconf -e "mydomain = $DOMAIN"
postconf -e 'myorigin = $mydomain'
postconf -e "mydestination = localhost"
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "mynetworks = 127.0.0.0/8"

postconf -e "virtual_mailbox_domains = hash:$POSTFIX_VDOMAINS"
postconf -e "virtual_mailbox_maps = hash:$POSTFIX_VMAILBOX"
postconf -e "virtual_mailbox_base = $VMAIL_BASE"
postconf -e "virtual_uid_maps = static:5000"
postconf -e "virtual_gid_maps = static:5000"
postconf -e "virtual_transport = virtual"

postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_tls_auth_only = yes"
postconf -e "smtpd_recipient_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination"

postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/$MAIL_HOST/fullchain.pem"
postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/$MAIL_HOST/privkey.pem"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtpd_tls_security_level = may"
postconf -e "smtp_tls_security_level = may"

if ! grep -q '^submission inet' /etc/postfix/master.cf; then
cat >> /etc/postfix/master.cf <<'EOF2'

submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

smtps     inet  n       -       n       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
EOF2
fi

postfix check
systemctl enable --now postfix
systemctl restart postfix

postconf -n | egrep 'myhostname|mydomain|virtual_mailbox|sasl|tls|recipient_restrictions' || true
ss -tulpn | egrep ':25|:465|:587' || true
