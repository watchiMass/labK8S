#!/usr/bin/env bash
# Synchronise le repo local cka-practice-labs vers base:~/cka-practice-labs.
# Par défaut, ne supprime rien dans la VM (pour ne pas effacer votre travail).
# Utilisez --prune pour un miroir exact.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="${ROOT}/provision/.lab_key"
SRC="${ROOT}/cka-practice-labs/"
DEST="candidate@192.168.56.10:/home/candidate/cka-practice-labs/"

if [[ ! -f "${KEY}" ]]; then
  echo "Clé labo absente (${KEY}). Lancez 'vagrant up' d'abord." >&2
  exit 1
fi
if [[ ! -d "${SRC}" ]]; then
  echo "Répertoire source introuvable : ${SRC}" >&2
  exit 1
fi

ARGS=(-az --exclude 'tools/' --exclude '.git/')
if [[ "${1:-}" == "--prune" ]]; then
  ARGS+=(--delete)
fi

rsync "${ARGS[@]}" \
  -e "ssh -i ${KEY} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR" \
  "${SRC}" "${DEST}"

echo "Labs synchronisés vers base:~/cka-practice-labs"
