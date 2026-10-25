#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_command blender
require_env BLEND_FILE
require_env FRAME_START
require_env FRAME_END

if [[ ! -f "$BLEND_FILE" ]]; then
  printf '找不到 Blender 工程: %s\n' "$BLEND_FILE" >&2
  exit 1
fi
if ! [[ "$FRAME_START" =~ ^-?[0-9]+$ && "$FRAME_END" =~ ^-?[0-9]+$ ]]; then
  printf 'FRAME_START 和 FRAME_END 必须是整数。\n' >&2
  exit 1
fi
if (( FRAME_END < FRAME_START )); then
  printf 'FRAME_END 不能小于 FRAME_START。\n' >&2
  exit 1
fi

mkdir -p "$RENDER_DIR" "$LOG_DIR"
"$SCRIPT_DIR/preflight.sh"

"$SCRIPT_DIR/r2-upload-loop.sh" &
uploader_pid=$!

cleanup() {
  if kill -0 "$uploader_pid" 2>/dev/null; then
    kill "$uploader_pid" 2>/dev/null || true
    wait "$uploader_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

set +e
blender --factory-startup --disable-autoexec --background \
  --python "$SCRIPT_DIR/enable-mmd-tools.py" \
  "$BLEND_FILE" \
  -o "$RENDER_DIR/######" \
  -F PNG \
  -s "$FRAME_START" \
  -e "$FRAME_END" \
  -a 2>&1 | tee "$LOG_DIR/blender-render.log"
render_status=${PIPESTATUS[0]}
set -e

cleanup
trap - EXIT INT TERM

"$SCRIPT_DIR/finalize-and-verify.sh"

if (( render_status != 0 )); then
  printf 'Blender 返回错误码 %s；已上传现有完整 PNG，但渲染任务未成功完成。\n' "$render_status" >&2
  exit "$render_status"
fi

printf '渲染、最终上传和数量/大小核对已完成。\n'

