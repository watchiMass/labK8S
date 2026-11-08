#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-a/q13-helm-rollback"
if kubectl cluster-info >/dev/null 2>&1; then
  if command -v helm >/dev/null 2>&1; then
    helm uninstall web -n a13-helm >/dev/null 2>&1 || true
  fi
  kubectl delete namespace a13-helm --ignore-not-found >/dev/null 2>&1 || true
fi
rm -rf "$QWORK/webchart"
info "Cleaned up release web, namespace a13-helm and the chart."
