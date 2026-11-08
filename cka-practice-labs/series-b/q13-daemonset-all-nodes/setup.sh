#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q13-daemonset-all-nodes"
ensure_workdir "$QWORK"

kubectl create namespace b13-ds --dry-run=client -o yaml | kubectl apply -f - >/dev/null
info "Environment ready. Namespace: b13-ds"
