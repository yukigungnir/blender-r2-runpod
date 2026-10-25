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

if ! [[ "$R2_MIN_FREE_GB" =~ ^[0-9]+$ && "$R2_DISK_CHECK_SECONDS" =~ ^[0-9]+$ ]]; then
  printf 'R2_MIN_FREE_GB 和 R2_DISK_CHECK_SECONDS 必须是非负整数。\n' >&2
  exit 1
fi

effective_start="$FRAME_START"
remote_list="$(mktemp)"
if [[ "$R2_RESUME_FROM_REMOTE" == "1" ]]; then
  rclone lsf "$(remote_path)" --files-only --include '*.png' > "$remote_list"
  effective_start="$(awk -v start="$FRAME_START" -v end="$FRAME_END" '
    /^[0-9][0-9][0-9][0-9][0-9][0-9]\.png$/ {
      frame = $0
      sub(/\.png$/, "", frame)
      seen[frame + 0] = 1
    }
    END {
      for (i = start; i <= end; i++) {
        if (!(i in seen)) {
          print i
          found = 1
          exit
        }
      }
      if (!found) print end + 1
    }
  ' "$remote_list")"
fi
rm -f -- "$remote_list"

if (( effective_start > FRAME_END )); then
  printf 'R2 已包含 %s 到 %s 的全部帧，跳过重复渲染。\n' "$FRAME_START" "$FRAME_END"
  "$SCRIPT_DIR/finalize-and-verify.sh"
  exit 0
fi

printf '本次从第 %s 帧开始，目标结束帧为 %s。\n' "$effective_start" "$FRAME_END"

"$SCRIPT_DIR/r2-upload-loop.sh" &
uploader_pid=$!
blender_pid=''
guard_pid=''

cleanup() {
  local pid
  for pid in "$guard_pid" "$blender_pid" "$uploader_pid"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT INT TERM

set +e
blender --factory-startup --disable-autoexec --background \
  --python "$SCRIPT_DIR/enable-mmd-tools.py" \
  "$BLEND_FILE" \
  -o "$RENDER_DIR/######" \
  -F PNG \
  -s "$effective_start" \
  -e "$FRAME_END" \
  -a > >(tee "$LOG_DIR/blender-render.log") 2>&1 &
blender_pid=$!
set -e

(
  threshold_kib=$((R2_MIN_FREE_GB * 1024 * 1024))
  while kill -0 "$blender_pid" 2>/dev/null; do
    free_kib="$(available_kib)"
    if [[ "$free_kib" =~ ^[0-9]+$ ]] && (( free_kib < threshold_kib )); then
      printf '{"time":"%s","status":"render_stopped_low_space","free_kib":%s,"minimum_kib":%s}\n' \
        "$(timestamp)" "$free_kib" "$threshold_kib" \
        | tee "$LOG_DIR/disk-space-stop.json" >&2
      kill "$blender_pid" 2>/dev/null || true
      exit 0
    fi
    sleep "$R2_DISK_CHECK_SECONDS"
  done
) &
guard_pid=$!

set +e
wait "$blender_pid"
render_status=$?
set -e
blender_pid=''

if kill -0 "$guard_pid" 2>/dev/null; then
  kill "$guard_pid" 2>/dev/null || true
  wait "$guard_pid" 2>/dev/null || true
fi
guard_pid=''

cleanup
trap - EXIT INT TERM

if (( render_status != 0 )); then
  FINAL_UPLOAD=1 "$SCRIPT_DIR/r2-upload-pass.sh"
  printf 'Blender 返回错误码 %s；现有完整 PNG 已上传。下次启动会从 R2 中最早缺失的帧继续。\n' "$render_status" >&2
  exit "$render_status"
fi

"$SCRIPT_DIR/finalize-and-verify.sh"

printf '渲染、流式上传、本地清理和远端帧清单核对已完成。\n'
