#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
need_cmd openssl "Install openssl and re-run."
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

$SUDO test -s /etc/kubernetes/pki/apiserver.crt \
  || die "/etc/kubernetes/pki/apiserver.crt not found; this question expects a kubeadm control plane."

rm -f "$QWORK/expiration" "$QWORK/kubeadm-renew-certs.sh"
info "Environment ready. Work directory: $QWORK"
