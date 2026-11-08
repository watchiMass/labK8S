#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace a10-staging a10-prod --ignore-not-found >/dev/null 2>&1 || true
fi
rm -rf "$QWORK/base" "$QWORK/overlays"
info "Cleaned up namespaces a10-staging/a10-prod and the Kustomize files."
