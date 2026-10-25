#!/usr/bin/env bash
set -Eeuo pipefail

: "${RENDER_DIR:=/workspace/render/frames}"
: "${LOG_DIR:=/workspace/logs}"
: "${R2_PREFIX:=castorice_vertical/frames}"
: "${R2_INTERVAL_SECONDS:=120}"
: "${R2_MIN_AGE:=2m}"
: "${R2_TRANSFERS:=4}"
: "${R2_CHECKERS:=8}"
: "${R2_DELETE_AFTER_UPLOAD:=1}"
: "${R2_RESUME_FROM_REMOTE:=1}"
: "${R2_MIN_FREE_GB:=5}"
: "${R2_DISK_CHECK_SECONDS:=30}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '缺少命令: %s\n' "$1" >&2
    return 1
  }
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    printf '缺少必需环境变量: %s\n' "$name" >&2
    return 1
  fi
}

validate_r2_env() {
  local name
  for name in \
    RCLONE_CONFIG_R2_TYPE \
    RCLONE_CONFIG_R2_PROVIDER \
    RCLONE_CONFIG_R2_ENDPOINT \
    RCLONE_CONFIG_R2_ACCESS_KEY_ID \
    RCLONE_CONFIG_R2_SECRET_ACCESS_KEY \
    R2_BUCKET; do
    require_env "$name"
  done
}

remote_path() {
  printf 'r2:%s/%s' "$R2_BUCKET" "${R2_PREFIX#/}"
}

timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

count_local_png() {
  find "$RENDER_DIR" -maxdepth 1 -type f -iname '*.png' -printf '.' 2>/dev/null | wc -c | tr -d ' '
}

count_remote_png() {
  rclone lsf "$(remote_path)" --files-only --include '*.png' 2>/dev/null | wc -l | tr -d ' '
}

bytes_local_png() {
  find "$RENDER_DIR" -maxdepth 1 -type f -iname '*.png' -printf '%s\n' 2>/dev/null \
    | awk '{sum += $1} END {printf "%.0f", sum + 0}'
}

bytes_remote_png() {
  rclone size "$(remote_path)" --include '*.png' --json 2>/dev/null \
    | sed -n 's/.*"bytes"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
    | head -n 1
}

available_kib() {
  df -Pk "$RENDER_DIR" | awk 'NR == 2 {print $4}'
}

write_status() {
  local status="$1"
  local local_count="${2:-0}"
  local remote_count="${3:-0}"
  mkdir -p "$LOG_DIR"
  printf '{"time":"%s","status":"%s","local_count":%s,"remote_count":%s}\n' \
    "$(timestamp)" "$status" "$local_count" "$remote_count" \
    > "$LOG_DIR/r2-upload-status.json"
}
