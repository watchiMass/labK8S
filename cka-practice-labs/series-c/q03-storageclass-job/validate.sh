#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c3-storage
info "Validating StorageClass, PVC, PV and Job..."

sc=$(kubectl get storageclass local-backup -o jsonpath='{.provisioner}' 2>/dev/null || true)
check_eq "StorageClass local-backup uses rancher.io/local-path" "$sc" "rancher.io/local-path"

vbm=$(kubectl get storageclass local-backup -o jsonpath='{.volumeBindingMode}' 2>/dev/null || true)
check_eq "StorageClass uses WaitForFirstConsumer" "$vbm" "WaitForFirstConsumer"

reclaim=$(kubectl get storageclass local-backup -o jsonpath='{.reclaimPolicy}' 2>/dev/null || true)
check_eq "StorageClass reclaim policy is Retain" "$reclaim" "Retain"

size=$(kubectl -n "$NS" get pvc backup-pvc -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || true)
check_eq "PVC requests 50Mi" "$size" "50Mi"

pvc_sc=$(kubectl -n "$NS" get pvc backup-pvc -o jsonpath='{.spec.storageClassName}' 2>/dev/null || true)
check_eq "PVC uses local-backup" "$pvc_sc" "local-backup"

for _ in $(seq 1 30); do
  pvc_phase=$(kubectl -n "$NS" get pvc backup-pvc -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "$pvc_phase" == "Bound" ]] && break
  sleep 2
done
check_eq "PVC is Bound" "$pvc_phase" "Bound"

pv=$(kubectl -n "$NS" get pvc backup-pvc -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)
if [[ -n "$pv" ]]; then
  pass "PVC is bound to PV $pv"
  claim_ns=$(kubectl get pv "$pv" -o jsonpath='{.spec.claimRef.namespace}' 2>/dev/null || true)
  claim_name=$(kubectl get pv "$pv" -o jsonpath='{.spec.claimRef.name}' 2>/dev/null || true)
  check_eq "PV claimRef points at backup-pvc in c3-storage" "$claim_ns/$claim_name" "$NS/backup-pvc"
  pv_reclaim=$(kubectl get pv "$pv" -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null || true)
  if [[ "$pv_reclaim" != "Retain" ]]; then
    warn "The provisioner created the PV with reclaim policy '$pv_reclaim'; the StorageClass itself is correct."
  fi
else
  fail "PVC is not bound to a PV"
fi

for _ in $(seq 1 90); do
  succeeded=$(kubectl -n "$NS" get job backup -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
  [[ "$succeeded" == "1" ]] && break
  sleep 2
done
check_eq "Job backup completed exactly once" "$succeeded" "1"

claims=$(kubectl -n "$NS" get job backup \
  -o jsonpath='{range .spec.template.spec.volumes[*]}{.persistentVolumeClaim.claimName}{"\n"}{end}' 2>/dev/null || true)
if grep -qx 'backup-pvc' <<<"$claims"; then
  pass "Job mounts PVC backup-pvc"
else
  fail "Job does not mount PVC backup-pvc"
fi

mount=$(kubectl -n "$NS" get job backup \
  -o jsonpath='{range .spec.template.spec.containers[0].volumeMounts[*]}{.mountPath}{"\n"}{end}' 2>/dev/null || true)
if grep -q '^/backup$' <<<"$mount"; then
  pass "Job mounts the PVC at /backup"
else
  fail "Job does not mount the PVC at /backup (got '$mount')"
fi

logs=$(kubectl -n "$NS" logs job/backup 2>/dev/null || true)
if grep -Eq '[0-9]{4}' <<<"$logs"; then
  pass "Job logs show the written backup date"
else
  fail "Job logs do not show a written date"
fi

if kubectl -n "$NS" rollout status job/backup --timeout=5s >/dev/null 2>&1; then
  pass "Job reports a successful completion"
else
  warn "Could not use rollout status for the Job; the succeeded count is authoritative."
fi

summary
