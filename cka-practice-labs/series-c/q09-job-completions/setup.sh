#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-c/q09-job-completions"
ensure_workdir "$QWORK"

kubectl create namespace c9-job --dry-run=client -o yaml | kubectl apply -f - >/dev/null
info "Environment ready. Namespace: c9-job"
