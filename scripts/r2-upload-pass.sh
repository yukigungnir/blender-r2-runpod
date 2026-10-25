#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_command rclone
validate_r2_env
mkdir -p "$RENDER_DIR" "$LOG_DIR"

extra_age=()
if [[ "${FINAL_UPLOAD:-0}" != "1" ]]; then
  extra_age=(--min-age "$R2_MIN_AGE")
fi

transfer_command=copy
status_name=success_copy
if [[ "$R2_DELETE_AFTER_UPLOAD" == "1" ]]; then
  transfer_command=move
  status_name=success_move
fi

rclone "$transfer_command" "$RENDER_DIR" "$(remote_path)" \
  --include '*.png' \
  "${extra_age[@]}" \
  --checksum \
  --transfers "$R2_TRANSFERS" \
  --checkers "$R2_CHECKERS" \
  --retries 10 \
  --low-level-retries 20 \
  --retries-sleep 15s \
  --contimeout 30s \
  --timeout 5m \
  --stats 30s \
  --stats-one-line-date \
  --log-level INFO \
  --log-file "$LOG_DIR/r2-upload.log"

local_count="$(count_local_png)"
remote_count="$(count_remote_png)"
write_status "$status_name" "$local_count" "$remote_count"
