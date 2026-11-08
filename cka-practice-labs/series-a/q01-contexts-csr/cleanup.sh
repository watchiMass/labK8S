#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace a1-dev --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete csr dev-anna --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$QWORK/dev-anna.key" "$QWORK/dev-anna.csr" "$QWORK/dev-anna.crt" \
      "$QWORK/dev-anna.kubeconfig" "$QWORK/ca.crt"
info "Cleaned up namespace a1-dev, CSR dev-anna and generated files in $QWORK."
