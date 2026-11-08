#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-a/q11-kustomize-overlay"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace a11-staging a11-prod --ignore-not-found >/dev/null 2>&1 || true
fi
rm -rf "$QWORK/base" "$QWORK/overlays"
info "Cleaned up namespaces a11-staging/a11-prod and the Kustomize files."
