#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
BACKUP="$QWORK/kube-scheduler.yaml.orig"

if [[ -f "$BACKUP" ]]; then
  need_root_or_sudo
  $SUDO cp "$BACKUP" /etc/kubernetes/manifests/kube-scheduler.yaml
  info "Restored the kube-scheduler static manifest."
fi

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete pod manual-schedule manual-schedule2 -n default --ignore-not-found >/dev/null 2>&1 || true
fi
rm -f "$BACKUP" "$QWORK/node.txt"
info "Cleanup complete."
