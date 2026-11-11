#!/usr/bin/env bash
# Affiche l'état du desktop d'examen : propriétés des répertoires, unités
# systemd et derniers logs. À coller dans le chat en cas de problème.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="${ROOT}/provision/.lab_key"

if [[ ! -f "${KEY}" ]]; then
  echo "Clé labo absente (${KEY}). Lancez 'vagrant up' d'abord." >&2
  exit 1
fi

ssh -i "${KEY}" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  candidate@192.168.56.10 'bash -s' <<'EOF'
echo "== whoami =="
id
echo "== home dirs =="
ls -ld /home/candidate /home/candidate/.config /home/candidate/.config/VSCodium \
       /home/candidate/.vscode-oss /home/candidate/.mozilla /home/candidate/.config/xfce4 2>&1
echo "== runtime dirs =="
ls -ld /run/cka-desktop /run/user/* 2>&1
echo "== unit env =="
systemctl show exam-desktop -p User -p Environment 2>&1
systemctl show exam-console -p User -p Environment 2>&1
echo "== services =="
systemctl is-active exam-xvfb exam-desktop exam-vnc exam-novnc exam-console xrdp 2>&1
echo "== desktop journal (20 dernières lignes) =="
journalctl -u exam-desktop -n 20 --no-pager 2>&1
EOF
