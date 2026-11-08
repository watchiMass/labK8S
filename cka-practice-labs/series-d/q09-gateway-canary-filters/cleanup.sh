#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-d/q09-gateway-canary-filters"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace d09-gw --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$QWORK/gateway.yaml"
info "Cleaned up namespace d09-gw (Gateway API CRDs are left installed)."
