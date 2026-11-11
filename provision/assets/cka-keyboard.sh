#!/usr/bin/env bash
# Bascule le clavier du desktop d'examen entre FR et US.
set -euo pipefail

export DISPLAY="${DISPLAY:-:1}"

case "${1:-}" in
  fr|us)
    setxkbmap "$1"
    echo "Keyboard layout: $1"
    ;;
  *)
    echo "Usage: cka-keyboard fr|us" >&2
    exit 2
    ;;
esac
