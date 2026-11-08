#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-d/q01-validating-admission-policy"
ensure_workdir "$QWORK"

if ! kubectl api-resources --api-group=admissionregistration.k8s.io -o name 2>/dev/null \
  | grep -q 'validatingadmissionpolicies'; then
  die "ValidatingAdmissionPolicy is not available. Kubernetes 1.30+ is required."
fi

kubectl delete validatingadmissionpolicybinding d01-pod-rules-binding --ignore-not-found >/dev/null 2>&1 || true
kubectl delete validatingadmissionpolicy d01-pod-rules --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace d01-policy --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n d01-policy delete pod d01-invalid d01-prod d01-valid --ignore-not-found >/dev/null 2>&1 || true
kubectl -n default delete pod d01-default --ignore-not-found >/dev/null 2>&1 || true

info "Environment ready. Namespace: d01-policy (Kubernetes supports ValidatingAdmissionPolicy)."
