#!/usr/bin/env bash
# Bascule Firefox entre le mode examen (docs Kubernetes uniquement) et ouvert.
set -euo pipefail

POL="/etc/firefox/policies/policies.json"
case "${1:-}" in
  restricted)
    install -m 0644 /usr/local/share/cka/firefox-policies-restricted.json "$POL"
    ;;
  open)
    install -m 0644 /usr/local/share/cka/firefox-policies-open.json "$POL"
    ;;
  *)
    echo "Usage: sudo cka-firefox-mode restricted|open" >&2
    exit 2
    ;;
esac
echo "Firefox mode: $1 (relancez Firefox pour appliquer)."
