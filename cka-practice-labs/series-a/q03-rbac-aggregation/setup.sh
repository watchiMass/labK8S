#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace a3-agg --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a3-agg create serviceaccount metrics-agent --dry-run=client -o yaml | kubectl apply -f - >/dev/null

info "Environment ready. Work directory: $QWORK"
