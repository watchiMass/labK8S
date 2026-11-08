#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_root_or_sudo
$SUDO rm -f /etc/kubernetes/manifests/my-static-pod.yaml
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete service static-pod-service -n default --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete pod -l app=my-static-pod -n default --ignore-not-found >/dev/null 2>&1 || true
fi
info "Removed the static Pod manifest and the Service."
