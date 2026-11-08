#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace a12-crd --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete crd widgets.stable.example.com --ignore-not-found >/dev/null 2>&1 || true
fi
info "Cleaned up namespace a12-crd and the Widget CRD."
