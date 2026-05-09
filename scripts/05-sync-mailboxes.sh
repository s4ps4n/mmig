#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

if [ ! -f "$MAILBOXES_CSV" ]; then
  echo "ERROR: CSV not found: $MAILBOXES_CSV" >&2
  exit 1
fi

mkdir -p "$LOGDIR"
REPORT="$LOGDIR/sync-report-$(date +%F_%H-%M-%S).txt"

echo "SYNC REPORT: $(date)" | tee "$REPORT"

tail -n +2 "$MAILBOXES_CSV" | while IFS=',' read -r email app_password new_password maxage; do
  email=$(echo "$email" | tr -d '\r' | xargs)
  app_password=$(echo "$app_password" | tr -d '\r')
  new_password=$(echo "$new_password" | tr -d '\r')
  maxage=$(echo "$maxage" | tr -d '\r' | xargs)

  [ -z "$email" ] && continue
  [ -z "$maxage" ] && maxage=30

  safe_email=$(safe_name "$email")
  logfile="$LOGDIR/${safe_email}_maxage_${maxage}_$(date +%F_%H-%M-%S).log"

  echo "==========================================" | tee -a "$REPORT"
  echo "SYNC: $email" | tee -a "$REPORT"
  echo "MAXAGE: $maxage days" | tee -a "$REPORT"
  echo "LOG: $logfile" | tee -a "$REPORT"
  echo "START: $(date)" | tee -a "$REPORT"

  ssl1_args=()
  if [ "${OLD_IMAP_SSL:-yes}" = "yes" ]; then
    ssl1_args=(--ssl1)
  fi

  imapsync \
    --host1 "$OLD_IMAP_HOST" --port1 "$OLD_IMAP_PORT" "${ssl1_args[@]}" \
    --user1 "$email" --password1 "$app_password" \
    --host2 "$NEW_IMAP_HOST" --port2 "$NEW_IMAP_PORT" \
    --user2 "$email" --password2 "$new_password" \
    --automap \
    --regextrans2 's/\./_/g' \
    --regextrans2 's/:/_/g' \
    --regextrans2 's/\\/_/g' \
    --regextrans2 's/\[/_/g' \
    --regextrans2 's/\]/_/g' \
    --regextrans2 's/\*/_/g' \
    --regextrans2 's/\?/_/g' \
    --regextrans2 's#/+$##' \
    --syncinternaldates \
    --noauthmd5 \
    --maxage "$maxage" \
    --nofoldersizes \
    --skipsize \
    --usecache \
    --errorsmax 50 \
    2>&1 | tee "$logfile"

  code=${PIPESTATUS[0]}
  if [ "$code" -eq 0 ]; then
    echo "OK: $email" | tee -a "$REPORT"
  else
    echo "FAIL: $email, exit code: $code" | tee -a "$REPORT"
  fi
  echo "END: $(date)" | tee -a "$REPORT"
done

echo "DONE: $(date)" | tee -a "$REPORT"
