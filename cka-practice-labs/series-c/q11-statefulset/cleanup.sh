#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace c11-sts --ignore-not-found >/dev/null 2>&1 || true
  for pv in $(kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="c11-sts")]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
  done
fi
info "Cleaned up namespace c11-sts and any retained PVs."
