#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-d/q14-node-debug"
ensure_workdir "$QWORK"

WORKER=$(first_worker)
[[ -n "$WORKER" ]] || die "No worker node found."
printf '%s\n' "$WORKER" >"$QWORK/node.txt"
rm -f "$QWORK/node-report.txt"

info "Environment ready. Inspect worker: $WORKER (recorded in node.txt)"
