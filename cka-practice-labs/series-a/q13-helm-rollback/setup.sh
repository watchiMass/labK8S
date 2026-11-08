#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_cmd helm "Install Helm 3 and re-run."
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace a13-helm --dry-run=client -o yaml | kubectl apply -f - >/dev/null
helm uninstall web -n a13-helm >/dev/null 2>&1 || true
rm -rf "$QWORK/webchart"

info "Environment ready. Work directory: $QWORK"
