#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace a6-front a6-back --ignore-not-found >/dev/null 2>&1 || true
fi
info "Cleaned up namespaces a6-front and a6-back."
