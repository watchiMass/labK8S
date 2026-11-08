#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$CKA_WORKROOT/series-b/q15-cluster-events"
ensure_workdir "$QWORK"

if ! $SUDO crictl ps >/dev/null 2>&1; then
  if [[ ! -f /etc/crictl.yaml && ! -f /etc/crictl.yaml.cka-orig ]]; then
    printf '%s\n' \
      'runtime-endpoint: unix:///run/containerd/containerd.sock' \
      'image-endpoint: unix:///run/containerd/containerd.sock' \
      'timeout: 10' 'debug: false' \
      | $SUDO tee /etc/crictl.yaml >/dev/null
    printf 'created\n' >"$QWORK/crictl-created"
  fi
  $SUDO crictl ps >/dev/null 2>&1 \
    || die "crictl cannot reach the container runtime. Configure /etc/crictl.yaml and re-run."
fi

kubectl create namespace b15-events --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n b15-events apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: event-target
  labels:
    app: event-target
spec:
  selector:
    matchLabels:
      app: event-target
  template:
    metadata:
      labels:
        app: event-target
    spec:
      tolerations:
        - operator: Exists
      containers:
        - name: nginx
          image: nginx:1-alpine
YAML

kubectl -n b15-events rollout status daemonset/event-target --timeout=180s >/dev/null
rm -f "$QWORK/cluster_events.sh" "$QWORK/pod_kill.log" "$QWORK/container_kill.log"

info "Environment ready. Namespace: b15-events (one target Pod per node, including control plane)"
