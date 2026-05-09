#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_DIR/config.env}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: config.env not found. Copy config.env.example to config.env and edit it." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "ERROR: run as root" >&2
    exit 1
  fi
}

require_confirm() {
  if [ "${CONFIRM_PRODUCTION:-no}" != "yes" ]; then
    echo "ERROR: set CONFIRM_PRODUCTION=\"yes\" in config.env after reviewing the script." >&2
    exit 1
  fi
}

backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    cp -a "$file" "$file.bak.$(date +%F_%H-%M-%S)"
  fi
}

mail_localpart() {
  local email="$1"
  echo "${email%@*}"
}

safe_name() {
  echo "$1" | sed 's/@/_/g; s/\./_/g; s/[^a-zA-Z0-9_-]/_/g'
}
