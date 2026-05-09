#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

getent group vmail >/dev/null || groupadd -g 5000 vmail
id vmail >/dev/null 2>&1 || useradd -g vmail -u 5000 vmail -d "$VMAIL_BASE" -m
mkdir -p "$VMAIL_BASE"
chown -R vmail:vmail "$VMAIL_BASE"
chmod 770 "$VMAIL_BASE"

touch "$DOVECOT_USERS"
chown root:dovecot "$DOVECOT_USERS"
chmod 640 "$DOVECOT_USERS"

backup_file /etc/dovecot/conf.d/10-auth.conf
backup_file /etc/dovecot/conf.d/10-mail.conf
backup_file /etc/dovecot/conf.d/10-master.conf
backup_file /etc/dovecot/conf.d/10-ssl.conf

cat > /etc/dovecot/conf.d/auth-passwdfile.conf.ext <<EOF2
passdb {
  driver = passwd-file
  args = scheme=SHA512-CRYPT username_format=%u $DOVECOT_USERS
}

userdb {
  driver = static
  args = uid=vmail gid=vmail home=$VMAIL_BASE/%d/%n
}
EOF2

sed -i 's/^!include auth-system.conf.ext/#!include auth-system.conf.ext/' /etc/dovecot/conf.d/10-auth.conf || true
grep -q 'auth-passwdfile.conf.ext' /etc/dovecot/conf.d/10-auth.conf || echo '!include auth-passwdfile.conf.ext' >> /etc/dovecot/conf.d/10-auth.conf

cat > /etc/dovecot/conf.d/10-mail.conf <<EOF2
mail_location = maildir:$VMAIL_BASE/%d/%n/Maildir

namespace inbox {
  inbox = yes
}
EOF2

cat > /etc/dovecot/conf.d/10-master.conf <<'EOF2'
service imap-login {
  inet_listener imap {
    port = 143
  }

  inet_listener imaps {
    port = 993
    ssl = yes
  }
}

service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF2

cat > /etc/dovecot/conf.d/10-ssl.conf <<EOF2
ssl = required
ssl_cert = </etc/letsencrypt/live/$MAIL_HOST/fullchain.pem
ssl_key = </etc/letsencrypt/live/$MAIL_HOST/privkey.pem
EOF2

systemctl enable --now dovecot
systemctl restart dovecot

dovecot -n | egrep -i 'mail_location|passwd-file|imaps|ssl|cert|key' -A3 -B3 || true
