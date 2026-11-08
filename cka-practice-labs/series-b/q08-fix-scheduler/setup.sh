#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$CKA_WORKROOT/series-b/q08-fix-scheduler"
ensure_workdir "$QWORK"

MANIFEST=/etc/kubernetes/manifests/kube-scheduler.yaml
BACKUP="$QWORK/kube-scheduler.yaml.orig"

if $SUDO test -s "$BACKUP"; then
  $SUDO cp "$BACKUP" "$MANIFEST"
fi
$SUDO test -s "$MANIFEST" || die "$MANIFEST is missing. Restore it and retry."

# Start from a clean manifest even if a previous run left the bad flag behind.
$SUDO sed -i '/this-flag-was-injected/d' "$MANIFEST"
$SUDO cp "$MANIFEST" "$BACKUP"
$SUDO chown "$(id -u):$(id -g)" "$BACKUP" 2>/dev/null || true

$SUDO sed -i -E 's#^([[:space:]]*)- kube-scheduler$#\1- kube-scheduler\n\1- --this-flag-was-injected=true#' "$MANIFEST"

if $SUDO grep -q 'this-flag-was-injected' "$MANIFEST"; then
  info "Injected an invalid scheduler flag. The static Pod should crash-loop."
else
  die "Could not inject the fault into $MANIFEST (unexpected format)."
fi

sleep 8
info "Question prepared. Work directory: $QWORK"
