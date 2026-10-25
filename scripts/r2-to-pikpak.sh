#!/usr/bin/env bash
set -Eeuo pipefail

: "${R2_BUCKET:?必须设置 R2_BUCKET}"
: "${R2_PREFIX:=castorice_vertical/frames}"
: "${PIKPAK_DEST:=pikpak:Castorice/frames}"
: "${PIKPAK_TRANSFERS:=2}"

command -v rclone >/dev/null 2>&1 || {
  printf '缺少 rclone。\n' >&2
  exit 1
}

if ! rclone listremotes | grep -Fxq 'r2:'; then
  printf '未找到 r2: remote。请先运行 rclone config。\n' >&2
  exit 1
fi
if ! rclone listremotes | grep -Fxq 'pikpak:'; then
  printf '未找到 pikpak: remote。请先在可信机器运行 rclone config，选择 PikPak 后端。\n' >&2
  exit 1
fi

rclone copy "r2:${R2_BUCKET}/${R2_PREFIX#/}" "$PIKPAK_DEST" \
  --include '*.png' \
  --transfers "$PIKPAK_TRANSFERS" \
  --checkers 4 \
  --retries 10 \
  --low-level-retries 20 \
  --stats 30s \
  --stats-one-line-date \
  --progress

printf 'R2 -> PikPak 复制完成；请抽样打开目标文件。\n'
