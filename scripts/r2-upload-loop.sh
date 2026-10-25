#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

mkdir -p "$LOG_DIR"
lock_dir="$LOG_DIR/.r2-upload-loop.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  printf '[%s] R2 循环备份已在运行，本进程退出。\n' "$(timestamp)"
  exit 0
fi
cleanup_lock() {
  rmdir -- "$lock_dir" 2>/dev/null || true
}
trap cleanup_lock EXIT INT TERM

"$SCRIPT_DIR/preflight.sh"
printf '[%s] R2 循环备份已启动，每 %s 秒检查一次。\n' "$(timestamp)" "$R2_INTERVAL_SECONDS"

consecutive_failures=0
while true; do
  if "$SCRIPT_DIR/r2-upload-pass.sh"; then
    consecutive_failures=0
    rm -f "$LOG_DIR/r2-upload.failed"
  else
    consecutive_failures=$((consecutive_failures + 1))
    local_count="$(count_local_png)"
    write_status "failed_${consecutive_failures}" "$local_count" 0
    printf '[%s] 第 %s 次连续上传失败；脚本会继续重试。\n' \
      "$(timestamp)" "$consecutive_failures" \
      | tee "$LOG_DIR/r2-upload.failed" >&2
  fi
  sleep "$R2_INTERVAL_SECONDS"
done

