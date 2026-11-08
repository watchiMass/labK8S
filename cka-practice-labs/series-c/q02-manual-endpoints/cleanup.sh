#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace c2-app c2-ext --ignore-not-found >/dev/null 2>&1 || true
fi
info "Cleaned up namespaces c2-app and c2-ext."
