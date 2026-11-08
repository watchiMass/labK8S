#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-d/q12-indexed-job"
ensure_workdir "$QWORK"

kubectl create namespace d12-job --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d12-job delete job indexed-batch --ignore-not-found >/dev/null 2>&1 || true
kubectl -n d12-job delete pods -l job-name=indexed-batch --ignore-not-found >/dev/null 2>&1 || true

info "Environment ready. Namespace: d12-job"
