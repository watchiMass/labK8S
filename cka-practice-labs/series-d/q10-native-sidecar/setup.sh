#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-d/q10-native-sidecar"
ensure_workdir "$QWORK"

if ! kubectl explain pod.spec.initContainers.restartPolicy >/dev/null 2>&1; then
  die "Native sidecars (initContainer restartPolicy) are not supported by this cluster; Kubernetes 1.29+ is required."
fi

kubectl create namespace d10-sidecar --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d10-sidecar delete pod native-sidecar --ignore-not-found >/dev/null 2>&1 || true

info "Environment ready. Namespace: d10-sidecar"
