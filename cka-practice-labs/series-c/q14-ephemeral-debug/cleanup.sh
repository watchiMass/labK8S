#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-c/q14-ephemeral-debug"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace c14-debug --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$QWORK/pod-uid.txt"
info "Cleaned up namespace c14-debug."
