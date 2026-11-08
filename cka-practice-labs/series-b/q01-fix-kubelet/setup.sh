#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
need_cmd systemctl "This exercise expects a kubeadm/systemd node."
QWORK="$CKA_WORKROOT/series-b/q01-fix-kubelet"
ensure_workdir "$QWORK"

KCFG=/var/lib/kubelet/config.yaml
$SUDO test -f "$KCFG" || die "$KCFG not found; this question needs a kubeadm node."

if [[ ! -f "$QWORK/kubelet-config.yaml.orig" ]]; then
  $SUDO cp "$KCFG" "$QWORK/kubelet-config.yaml.orig"
  $SUDO chown "$(id -u):$(id -g)" "$QWORK/kubelet-config.yaml.orig" 2>/dev/null || true
fi

CA=$($SUDO grep -E '^[[:space:]]*clientCAFile:' "$QWORK/kubelet-config.yaml.orig" | awk '{print $2}' | tr -d '"' | head -n1 || true)
[[ -n "$CA" ]] || die "Could not find clientCAFile in $KCFG; unsupported kubelet config."

$SUDO sed -i -E "s#^([[:space:]]*clientCAFile:[[:space:]]*).*#\1${CA}.cka-broken#" "$KCFG"
$SUDO systemctl restart kubelet >/dev/null 2>&1 || true
sleep 8

if $SUDO systemctl is-active --quiet kubelet; then
  warn "kubelet is still active; wait a moment, it should crash-loop."
else
  info "kubelet is down as intended."
fi
info "Question prepared. Work directory: $QWORK"
