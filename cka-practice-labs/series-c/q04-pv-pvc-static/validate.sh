#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c4-storage
info "Validating static PV/PVC binding and mounted data..."

phase=$(kubectl -n "$NS" get pvc data-claim -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "PVC data-claim is Bound" "$phase" "Bound"

vol=$(kubectl -n "$NS" get pvc data-claim -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)
check_eq "PVC is bound to manual-pv" "$vol" "manual-pv"

size=$(kubectl -n "$NS" get pvc data-claim -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || true)
check_eq "PVC requests 50Mi" "$size" "50Mi"

sc=$(kubectl -n "$NS" get pvc data-claim -o jsonpath='{.spec.storageClassName}' 2>/dev/null || true)
check_eq "PVC uses StorageClass manual" "$sc" "manual"

pv_phase=$(kubectl get pv manual-pv -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "PV manual-pv is Bound" "$pv_phase" "Bound"

claim=$(kubectl get pv manual-pv -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}' 2>/dev/null || true)
check_eq "PV claimRef points at c4-storage/data-claim" "$claim" "$NS/data-claim"

pod_phase=$(kubectl -n "$NS" get pod storage-client -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "Pod storage-client is Running" "$pod_phase" "Running"

claims=$(kubectl -n "$NS" get pod storage-client \
  -o jsonpath='{range .spec.volumes[*]}{.persistentVolumeClaim.claimName}{"\n"}{end}' 2>/dev/null || true)
if grep -qx 'data-claim' <<<"$claims"; then
  pass "Pod mounts PVC data-claim"
else
  fail "Pod does not mount PVC data-claim"
fi

mount=$(kubectl -n "$NS" get pod storage-client \
  -o jsonpath='{range .spec.containers[0].volumeMounts[*]}{.mountPath}{"\n"}{end}' 2>/dev/null || true)
if grep -q '^/data$' <<<"$mount"; then
  pass "PVC is mounted at /data"
else
  fail "PVC is not mounted at /data"
fi

content=$(kubectl -n "$NS" exec storage-client -- cat /data/hello.txt 2>/dev/null || true)
check_eq "/data/hello.txt contains cka-rocks" "$(tr -d '\r\n' <<<"$content")" "cka-rocks"

summary
