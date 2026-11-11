#!/usr/bin/env bash
# Ouvre un shell (ou exécute une commande) sur base en tant que candidate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="${ROOT}/provision/.lab_key"

if [[ ! -f "${KEY}" ]]; then
  echo "Clé labo absente (${KEY}). Lancez 'vagrant up' d'abord." >&2
  exit 1
fi

exec ssh -i "${KEY}" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  candidate@192.168.56.10 "$@"
