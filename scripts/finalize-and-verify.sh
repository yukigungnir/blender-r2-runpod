#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

"$SCRIPT_DIR/preflight.sh"
FINAL_UPLOAD=1 "$SCRIPT_DIR/r2-upload-pass.sh"

local_count="$(count_local_png)"
remote_count="$(count_remote_png)"
local_bytes="$(bytes_local_png)"
remote_bytes="$(bytes_remote_png)"
remote_bytes="${remote_bytes:-0}"

status=ok
if [[ "$local_count" != "$remote_count" || "$local_bytes" != "$remote_bytes" ]]; then
  status=mismatch
fi

printf '{"time":"%s","status":"%s","local_count":%s,"remote_count":%s,"local_bytes":%s,"remote_bytes":%s}\n' \
  "$(timestamp)" "$status" "$local_count" "$remote_count" "$local_bytes" "$remote_bytes" \
  | tee "$LOG_DIR/final-summary.json"

if [[ "$status" != "ok" ]]; then
  printf '最终核对不一致；不要删除 Pod。请查看 %s 和上传日志。\n' "$LOG_DIR/final-summary.json" >&2
  exit 1
fi

printf '最终数量与总大小一致。仍需从 R2 抽样打开 PNG 后再删除 Pod。\n'
