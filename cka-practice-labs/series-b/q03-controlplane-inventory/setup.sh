#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q03-controlplane-inventory"
ensure_workdir "$QWORK"
rm -f "$QWORK/controlplane-components.txt"
info "Environment ready. Work directory: $QWORK"
