#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-c/q11-statefulset"
ensure_workdir "$QWORK"
ensure_local_path

kubectl delete namespace c11-sts --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace c11-sts --dry-run=client -o yaml | kubectl apply -f - >/dev/null

info "Environment ready. StorageClass local-path is available. Namespace: c11-sts"
