#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-d/q14-node-debug"
WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)

if kubectl cluster-info >/dev/null 2>&1 && [[ -n "$WORKER" ]]; then
  for pod in $(kubectl get pods -n default --field-selector "spec.nodeName=$WORKER" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep '^node-debugger-' || true); do
    kubectl delete pod "$pod" -n default --ignore-not-found >/dev/null 2>&1 || true
  done
fi

rm -f "$QWORK/node-report.txt" "$QWORK/node.txt"
info "Removed the report and any node-debugger Pod on $WORKER."
