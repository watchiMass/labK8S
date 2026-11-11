#!/usr/bin/env bash
# Capture le desktop XFCE d'examen (DISPLAY=:1) et la copie sur l'hôte.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="${ROOT}/provision/.lab_key"
OUT="${1:-/tmp/cka-desktop.png}"
SSH_OPTS=(-i "${KEY}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

if [[ ! -f "${KEY}" ]]; then
  echo "Clé labo absente (${KEY}). Lancez 'vagrant up' d'abord." >&2
  exit 1
fi

ssh "${SSH_OPTS[@]}" candidate@192.168.56.10 \
  'DISPLAY=:1 xfce4-screenshooter -f -s /tmp/cka-desktop.png'
scp "${SSH_OPTS[@]}" candidate@192.168.56.10:/tmp/cka-desktop.png "${OUT}"

echo "Capture enregistrée : ${OUT}"
