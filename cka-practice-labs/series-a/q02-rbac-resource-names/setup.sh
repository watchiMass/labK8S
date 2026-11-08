#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-a/q02-rbac-resource-names"
ensure_workdir "$QWORK"

kubectl create namespace a2-rbac --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a2-rbac create configmap app-config --from-literal=key=value --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a2-rbac create configmap app-config-2 --from-literal=key=value --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a2-rbac create configmap other-config --from-literal=key=value --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a2-rbac create serviceaccount auditor --dry-run=client -o yaml | kubectl apply -f - >/dev/null

info "Environment ready. Work directory: $QWORK"
