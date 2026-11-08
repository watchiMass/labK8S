#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"
ensure_local_path

kubectl create namespace c3-storage --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n c3-storage delete job backup --ignore-not-found >/dev/null 2>&1 || true
kubectl -n c3-storage delete pvc backup-pvc --ignore-not-found >/dev/null 2>&1 || true
for pv in $(kubectl get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="c3-storage")]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
  kubectl delete pv "$pv" --ignore-not-found >/dev/null 2>&1 || true
done
kubectl delete storageclass local-backup --ignore-not-found >/dev/null 2>&1 || true

cat > "$QWORK/backup.yaml" <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: backup
  namespace: c3-storage
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: backup
          image: busybox:1.36
          command:
            - sh
            - -c
            - date > /backup/backup.txt && cat /backup/backup.txt
          volumeMounts: []
      volumes: []
YAML

info "Environment ready. Job manifest: $QWORK/backup.yaml"
