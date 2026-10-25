#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

"$SCRIPT_DIR/preflight.sh"
FINAL_UPLOAD=1 "$SCRIPT_DIR/r2-upload-pass.sh"

local_count="$(count_local_png)"
remote_count="$(count_remote_png)"
remote_bytes="$(bytes_remote_png)"
remote_bytes="${remote_bytes:-0}"
expected_count=$((FRAME_END - FRAME_START + 1))

expected_list="$(mktemp)"
remote_list="$(mktemp)"
cleanup_lists() {
  rm -f -- "$expected_list" "$remote_list"
}
trap cleanup_lists EXIT

awk -v start="$FRAME_START" -v end="$FRAME_END" \
  'BEGIN { for (i = start; i <= end; i++) printf "%06d.png\n", i }' \
  > "$expected_list"
rclone lsf "$(remote_path)" --files-only --include '*.png' | sort > "$remote_list"

status=ok
if [[ "$remote_count" != "$expected_count" || "$remote_bytes" == "0" ]]; then
  status=mismatch
fi
if ! cmp -s "$expected_list" "$remote_list"; then
  status=mismatch
fi
if [[ "$R2_DELETE_AFTER_UPLOAD" == "1" && "$local_count" != "0" ]]; then
  status=local_cleanup_incomplete
fi

printf '{"time":"%s","status":"%s","expected_count":%s,"local_remaining":%s,"remote_count":%s,"remote_bytes":%s}\n' \
  "$(timestamp)" "$status" "$expected_count" "$local_count" "$remote_count" "$remote_bytes" \
  | tee "$LOG_DIR/final-summary.json"

if [[ "$status" != "ok" ]]; then
  printf '最终核对不一致；不要删除 Pod。请查看 %s 和上传日志。\n' "$LOG_DIR/final-summary.json" >&2
  exit 1
fi

printf 'R2 帧名和总帧数核对通过，本地已上传帧已清理。仍需从 R2 抽样打开 PNG 后再删除 Pod。\n'
