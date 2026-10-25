#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p /run/sshd /root/.ssh
chmod 0700 /root/.ssh

if [[ -n "${PUBLIC_KEY:-}" ]]; then
  printf '%s\n' "$PUBLIC_KEY" > /root/.ssh/authorized_keys
  chmod 0600 /root/.ssh/authorized_keys
fi

ssh-keygen -A
/usr/sbin/sshd

exec /opt/render-tools/r2-upload-loop.sh
