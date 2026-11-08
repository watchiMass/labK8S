#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace d08-kustomize --ignore-not-found >/dev/null 2>&1 || true
fi
rm -rf "$QWORK/base" "$QWORK/overlays" "$QWORK/components"
info "Cleaned up namespace d08-kustomize and the Kustomize tree."
