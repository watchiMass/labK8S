#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete validatingadmissionpolicybinding d01-pod-rules-binding --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete validatingadmissionpolicy d01-pod-rules --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete namespace d01-policy --ignore-not-found >/dev/null 2>&1 || true
fi
info "Cleaned up the policy, binding and namespace d01-policy."
