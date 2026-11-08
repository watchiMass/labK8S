#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-c/q14-ephemeral-debug"
NS=c14-debug
info "Validating ephemeral debug container..."

phase=$(kubectl -n "$NS" get pod target -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "Pod target is Running" "$phase" "Running"

uid=$(kubectl -n "$NS" get pod target -o jsonpath='{.metadata.uid}' 2>/dev/null || true)
recorded=$(cat "$QWORK/pod-uid.txt" 2>/dev/null || true)
check_eq "Pod target was not recreated (UID unchanged)" "$uid" "$recorded"

name=$(kubectl -n "$NS" get pod target \
  -o jsonpath='{.spec.ephemeralContainers[0].name}' 2>/dev/null || true)
image=$(kubectl -n "$NS" get pod target \
  -o jsonpath='{.spec.ephemeralContainers[0].image}' 2>/dev/null || true)
check_eq "ephemeral container is named debugger" "$name" "debugger"
check_eq "ephemeral container uses busybox:1.36" "$image" "busybox:1.36"

for _ in $(seq 1 30); do
  ep_phase=$(kubectl -n "$NS" get pod target \
    -o jsonpath='{.status.ephemeralContainerStatuses[0].state.running.startedAt}' 2>/dev/null || true)
  [[ -n "$ep_phase" ]] && break
  sleep 2
done
if [[ -n "${ep_phase:-}" ]]; then
  pass "ephemeral container debugger is running"
else
  fail "ephemeral container debugger is not running"
fi

if timeout 10 kubectl -n "$NS" exec target -c debugger -- true >/dev/null 2>&1; then
  pass "kubectl exec works inside the debugger container"
else
  fail "cannot exec into the debugger container"
fi

summary
