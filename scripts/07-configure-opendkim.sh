#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

mkdir -p "/etc/opendkim/keys/$DOMAIN"

if [ ! -f "/etc/opendkim/keys/$DOMAIN/${DKIM_SELECTOR}.private" ]; then
  opendkim-genkey -b 2048 -d "$DOMAIN" -D "/etc/opendkim/keys/$DOMAIN" -s "$DKIM_SELECTOR"
fi

chown -R opendkim:opendkim /etc/opendkim/keys
chmod 600 "/etc/opendkim/keys/$DOMAIN/${DKIM_SELECTOR}.private"

backup_file /etc/opendkim.conf

cat > /etc/opendkim.conf <<EOF2
Syslog yes
SyslogSuccess yes
LogWhy yes
UMask 002
Mode sv
Canonicalization relaxed/simple
Socket inet:8891@localhost
PidFile /run/opendkim/opendkim.pid
UserID opendkim:opendkim
KeyTable /etc/opendkim/KeyTable
SigningTable refile:/etc/opendkim/SigningTable
ExternalIgnoreList /etc/opendkim/TrustedHosts
InternalHosts /etc/opendkim/TrustedHosts
EOF2

cat > /etc/opendkim/TrustedHosts <<EOF2
127.0.0.1
localhost
$MAIL_HOST
$DOMAIN
$SERVER_IP
EOF2

cat > /etc/opendkim/KeyTable <<EOF2
${DKIM_SELECTOR}._domainkey.$DOMAIN $DOMAIN:$DKIM_SELECTOR:/etc/opendkim/keys/$DOMAIN/${DKIM_SELECTOR}.private
EOF2

cat > /etc/opendkim/SigningTable <<EOF2
*@$DOMAIN ${DKIM_SELECTOR}._domainkey.$DOMAIN
EOF2

postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 6"
postconf -e "smtpd_milters = inet:localhost:8891"
postconf -e "non_smtpd_milters = inet:localhost:8891"

systemctl enable --now opendkim
systemctl restart opendkim postfix

echo "OpenDKIM status:"
systemctl is-active opendkim || true
ss -tulpn | grep 8891 || true

echo "DNS TXT for DKIM:"
cat "/etc/opendkim/keys/$DOMAIN/${DKIM_SELECTOR}.txt"
