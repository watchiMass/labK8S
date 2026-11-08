#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-b/q12-taint-toleration"
if kubectl cluster-info >/dev/null 2>&1; then
  WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)
  if [[ -f "$QWORK/taint-added" && -n "$WORKER" ]]; then
    kubectl taint node "$WORKER" dedicated=cka:NoSchedule- >/dev/null 2>&1 || true
  fi
  kubectl delete namespace b12-pending --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$QWORK/node.txt" "$QWORK/taint-added"
info "Cleaned up the namespace and the taint this question added."
