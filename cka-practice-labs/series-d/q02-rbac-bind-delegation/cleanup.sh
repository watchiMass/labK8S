#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace d02-rbac --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete clusterrolebinding d02-delegator-binding d02-test-crb --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete clusterrole d02-delegator d02-pod-reader d02-secret-reader --ignore-not-found >/dev/null 2>&1 || true
fi
info "Cleaned up the RBAC objects and namespace d02-rbac."
