#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$CKA_WORKROOT/series-b/q07-manual-scheduling"
ensure_workdir "$QWORK"

MANIFEST=/etc/kubernetes/manifests/kube-scheduler.yaml
BACKUP="$QWORK/kube-scheduler.yaml.orig"

if $SUDO test -s "$BACKUP"; then
  $SUDO cp "$BACKUP" "$MANIFEST"
fi
$SUDO test -s "$MANIFEST" || die "$MANIFEST is missing; restore it (or run cleanup from a previous run) and retry."

$SUDO cp "$MANIFEST" "$BACKUP"
$SUDO chown "$(id -u):$(id -g)" "$BACKUP" 2>/dev/null || true

WORKER=$(first_worker)
[[ -n "$WORKER" ]] || die "No worker node found."
printf '%s\n' "$WORKER" >"$QWORK/node.txt"

kubectl delete pod manual-schedule manual-schedule2 -n default --ignore-not-found >/dev/null 2>&1 || true

info "Environment ready. Scheduler manifest: $MANIFEST"
info "Target worker: $WORKER"
