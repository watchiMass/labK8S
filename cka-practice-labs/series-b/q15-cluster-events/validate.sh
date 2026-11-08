#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
NS=b15-events
info "Validating event capture, logs and container restart..."

if [[ -s "$QWORK/cluster_events.sh" ]]; then
  pass "cluster_events.sh exists"
  if grep -q 'get events' "$QWORK/cluster_events.sh" \
     && grep -q 'metadata.creationTimestamp' "$QWORK/cluster_events.sh" \
     && grep -Eq -- '(-A|--all-namespaces)' "$QWORK/cluster_events.sh"; then
    pass "script contains a whole-cluster events command sorted by creationTimestamp"
  else
    fail "script is missing 'get events', all namespaces, or the creationTimestamp sort"
  fi
  if output=$(bash "$QWORK/cluster_events.sh" 2>/dev/null) && [[ -n "$output" ]]; then
    pass "cluster_events.sh runs and produces output"
  else
    fail "cluster_events.sh does not run successfully"
  fi
else
  fail "cluster_events.sh is missing"
fi

if [[ -s "$QWORK/pod_kill.log" ]]; then
  pass "pod_kill.log exists"
  if grep -q 'event-target' "$QWORK/pod_kill.log" \
     && grep -Eq 'Killing|Deleted|Scheduled|Started' "$QWORK/pod_kill.log"; then
    pass "pod_kill.log contains events for event-target"
  else
    fail "pod_kill.log does not contain the expected pod events"
  fi
else
  fail "pod_kill.log is missing"
fi

if [[ -s "$QWORK/container_kill.log" ]]; then
  pass "container_kill.log exists"
  if grep -q 'event-target' "$QWORK/container_kill.log"; then
    pass "container_kill.log mentions event-target"
  else
    fail "container_kill.log does not mention event-target"
  fi
else
  fail "container_kill.log is missing"
fi

CP=$(controlplane_node)
for _ in $(seq 1 45); do
  pod=$(kubectl -n "$NS" get pods --field-selector "spec.nodeName=$CP" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  [[ -n "$pod" ]] && break
  sleep 2
done

if [[ -z "${pod:-}" ]]; then
  fail "no event-target Pod found on the control-plane node"
else
  pass "found control-plane event-target Pod: $pod"
  restarts=$(kubectl -n "$NS" get pod "$pod" \
    -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || true)
  if [[ "${restarts:-0}" -ge 1 ]]; then
    pass "the nginx container was restarted by kubelet (restartCount=$restarts)"
  else
    fail "the nginx container restartCount is ${restarts:-0}; crictl kill was not performed"
  fi
  phase=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  check_eq "event-target Pod is Running again" "$phase" "Running"
fi

summary
