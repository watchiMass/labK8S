#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-c/q15-kubectl-sorting"
rm -f "$QWORK/find_pods.sh" "$QWORK/find_pods_uid.sh"
info "Removed the sorting scripts."
