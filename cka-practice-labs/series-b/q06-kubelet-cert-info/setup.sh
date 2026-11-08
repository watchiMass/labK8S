#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

WORKER=$(first_worker)
[[ -n "$WORKER" ]] || die "No worker node found."

printf '%s\n' "$WORKER" >"$QWORK/node.txt"
rm -f "$QWORK/certificate-info.txt"

info "Worker node recorded in $QWORK/node.txt: $WORKER"
