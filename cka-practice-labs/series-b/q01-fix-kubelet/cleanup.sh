#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-b/q01-fix-kubelet"
ORIG="$QWORK/kubelet-config.yaml.orig"

if [[ -f "$ORIG" ]]; then
  need_root_or_sudo
  $SUDO cp "$ORIG" /var/lib/kubelet/config.yaml
  $SUDO systemctl restart kubelet >/dev/null 2>&1 || true
  rm -f "$ORIG"
  info "Restored the original kubelet config and restarted kubelet."
else
  info "No saved kubelet config to restore."
fi

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete pod success -n default --ignore-not-found >/dev/null 2>&1 || true
fi
info "Cleanup complete."
