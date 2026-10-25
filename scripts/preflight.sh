#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_command rclone
validate_r2_env
mkdir -p "$RENDER_DIR" "$LOG_DIR"

printf 'Rclone: '
rclone version | head -n 1
if command -v blender >/dev/null 2>&1; then
  printf 'Blender: '
  blender --version | head -n 1
else
  printf 'Blender: 未找到（只运行上传脚本时可以忽略）\n'
fi

printf 'R2 凭证变量: 已注入（值不显示）\n'
printf '目标 Bucket 访问测试: '
rclone lsf "r2:${R2_BUCKET}" --max-depth 1 >/dev/null
printf '通过\n'
printf '本地目录: %s\n' "$RENDER_DIR"
printf '远端目录: %s\n' "$(remote_path)"
