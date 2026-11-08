#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace c4-storage --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete pv manual-pv --ignore-not-found >/dev/null 2>&1 || true
fi
info "Cleaned up namespace c4-storage and PV manual-pv."
