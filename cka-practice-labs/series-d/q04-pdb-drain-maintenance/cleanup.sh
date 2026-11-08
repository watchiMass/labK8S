#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
if kubectl cluster-info >/dev/null 2>&1; then
  WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)
  if [[ -n "$WORKER" ]]; then
    kubectl uncordon "$WORKER" >/dev/null 2>&1 || true
  fi
  kubectl delete namespace d04-maint --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$QWORK/node.txt"
info "Uncordoned the node and cleaned up namespace d04-maint."
