#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl delete namespace c4-storage --ignore-not-found >/dev/null 2>&1 || true
kubectl delete pv manual-pv --ignore-not-found >/dev/null 2>&1 || true

kubectl create namespace c4-storage --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
spec:
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/cka-manual-pv
    type: DirectoryOrCreate
YAML

info "Environment ready. PV manual-pv is Available. Work directory: $QWORK"
