#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

dnf install -y epel-release || true

dnf install -y \
  postfix dovecot dovecot-pigeonhole cyrus-sasl cyrus-sasl-plain \
  openssl s-nail telnet wget tar unzip bind-utils firewalld \
  certbot python3-certbot-nginx imapsync \
  opendkim opendkim-tools \
  php php-cli php-mbstring php-xml php-imap php-intl php-json \
  php-pdo php-mysqlnd php-gd php-zip php-sqlite3 php-process php-ldap php-pear \
  --allowerasing

echo "DONE: packages installed"
