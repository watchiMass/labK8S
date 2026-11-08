#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace b15-events --ignore-not-found >/dev/null 2>&1 || true
fi

if [[ -f "$QWORK/crictl-created" ]]; then
  need_root_or_sudo
  $SUDO rm -f /etc/crictl.yaml
fi
rm -f "$QWORK/crictl-created" "$QWORK/cluster_events.sh" \
      "$QWORK/pod_kill.log" "$QWORK/container_kill.log"
info "Cleaned up namespace b15-events, the reports and the generated crictl config."
