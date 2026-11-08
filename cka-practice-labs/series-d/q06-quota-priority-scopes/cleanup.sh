#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace d06-quota --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete priorityclass d06-high d06-low --ignore-not-found >/dev/null 2>&1 || true
fi
info "Cleaned up namespace d06-quota and the PriorityClasses."
