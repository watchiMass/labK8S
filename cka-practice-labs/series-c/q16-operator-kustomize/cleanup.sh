#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-c/q16-operator-kustomize"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace c16-operator --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete crd students.cka.example.com courses.cka.example.com --ignore-not-found >/dev/null 2>&1 || true
fi
rm -rf "$QWORK/base" "$QWORK/overlays" "$QWORK/crds"
info "Cleaned up namespace c16-operator, its CRDs and the Kustomize files."
