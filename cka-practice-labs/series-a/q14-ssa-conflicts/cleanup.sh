#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-a/q14-ssa-conflicts"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace a14-ssa --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$QWORK/base.yaml" "$QWORK/update.yaml"
info "Cleaned up namespace a14-ssa and the manifests."
