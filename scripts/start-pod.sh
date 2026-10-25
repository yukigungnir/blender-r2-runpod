#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p /run/sshd /root/.ssh
chmod 0700 /root/.ssh

if [[ -n "${PUBLIC_KEY:-}" ]]; then
  printf '%s\n' "$PUBLIC_KEY" > /root/.ssh/authorized_keys
  chmod 0600 /root/.ssh/authorized_keys
fi

ssh-keygen -A

uploader_supervisor() {
  while true; do
    if /opt/render-tools/r2-upload-loop.sh; then
      printf '[%s] R2 备份循环已退出，30 秒后重新启动。\n' "$(date -u +%FT%TZ)"
    else
      printf '[%s] R2 备份循环异常退出；SSH 保持可用，30 秒后重试。\n' "$(date -u +%FT%TZ)" >&2
    fi
    sleep 30
  done
}

uploader_supervisor &
uploader_pid=$!
cleanup() {
  kill "$uploader_pid" 2>/dev/null || true
  wait "$uploader_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

exec /usr/sbin/sshd -D -e
