#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-d/q07-crd-cel-validation"
ensure_workdir "$QWORK"

kubectl delete crd servers.stable.cka.io --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace d07-crd --dry-run=client -o yaml | kubectl apply -f - >/dev/null

info "Environment ready. Namespace: d07-crd"
