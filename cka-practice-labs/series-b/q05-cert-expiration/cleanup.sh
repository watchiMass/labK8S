#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-b/q05-cert-expiration"
rm -f "$QWORK/expiration" "$QWORK/kubeadm-renew-certs.sh"
info "Removed the certificate exercise files."
