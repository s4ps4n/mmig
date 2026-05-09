#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

systemctl enable --now firewalld || true

firewall-cmd --permanent --add-service=http || true
firewall-cmd --permanent --add-service=https || true
firewall-cmd --permanent --add-service=smtp || true
firewall-cmd --permanent --add-service=smtps || true
firewall-cmd --permanent --add-service=imap || true
firewall-cmd --permanent --add-service=imaps || true
firewall-cmd --permanent --add-port=587/tcp || true
firewall-cmd --reload || true
firewall-cmd --list-all || true
