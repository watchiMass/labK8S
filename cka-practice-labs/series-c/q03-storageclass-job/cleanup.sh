#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace c3-storage --ignore-not-found >/dev/null 2>&1 || true
  for pv in $(kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="c3-storage")]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
  done
  kubectl delete storageclass local-backup --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$QWORK/backup.yaml"
info "Cleaned up the Job, PVC/PV, StorageClass and namespace c3-storage."
