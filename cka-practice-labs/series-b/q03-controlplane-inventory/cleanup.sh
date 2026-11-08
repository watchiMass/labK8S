#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-b/q03-controlplane-inventory"
rm -f "$QWORK/controlplane-components.txt"
info "Removed the control-plane inventory report."
