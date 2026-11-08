#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace d16-token --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$QWORK/token.txt" "$QWORK/before.txt" "$QWORK/after.txt"
info "Cleaned up namespace d16-token and the token files."
