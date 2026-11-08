#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

$SUDO mkdir -p /etc/kubernetes/manifests
$SUDO rm -f /etc/kubernetes/manifests/my-static-pod.yaml
kubectl delete service static-pod-service -n default --ignore-not-found >/dev/null 2>&1 || true
kubectl delete pod -l app=my-static-pod -n default --ignore-not-found >/dev/null 2>&1 || true

info "Environment ready. Static manifests: /etc/kubernetes/manifests"
