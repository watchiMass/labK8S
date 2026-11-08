#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-a/q07-quota-limitrange"
ensure_workdir "$QWORK"

kubectl create namespace a7-quota --dry-run=client -o yaml | kubectl apply -f - >/dev/null

info "Environment ready. Work directory: $QWORK"
