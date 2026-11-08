#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c6-multi
POD=multi-container-playground
info "Validating multi-container Pod, shared volume and sidecars..."

phase=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "Pod is Running" "$phase" "Running"

containers=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)
count=$(wc -w <<<"$containers" | tr -d ' ')
check_eq "Pod has three containers" "$count" "3"
check_contains "container c1 exists" "$containers" "c1"
check_contains "container c2 exists" "$containers" "c2"
check_contains "container c3 exists" "$containers" "c3"

volname=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.volumes[0].name}' 2>/dev/null || true)
empty=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.volumes[0].emptyDir}' 2>/dev/null || true)
if [[ -n "$volname" && -n "$empty" ]]; then
  pass "volume $volname is an emptyDir"
else
  fail "the shared volume is not an emptyDir"
fi

c1_idx=""
c2_idx=""
c3_idx=""
for i in 0 1 2; do
  name=$(kubectl -n "$NS" get pod "$POD" -o jsonpath="{.spec.containers[$i].name}" 2>/dev/null || true)
  case "$name" in
    c1) c1_idx=$i ;;
    c2) c2_idx=$i ;;
    c3) c3_idx=$i ;;
  esac
done

if [[ -n "$c1_idx" && -n "$c2_idx" && -n "$c3_idx" && -n "$volname" ]]; then
  m1=$(kubectl -n "$NS" get pod "$POD" -o jsonpath="{.spec.containers[$c1_idx].volumeMounts[?(@.name==\"$volname\")].mountPath}" 2>/dev/null || true)
  m2=$(kubectl -n "$NS" get pod "$POD" -o jsonpath="{.spec.containers[$c2_idx].volumeMounts[?(@.name==\"$volname\")].mountPath}" 2>/dev/null || true)
  m3=$(kubectl -n "$NS" get pod "$POD" -o jsonpath="{.spec.containers[$c3_idx].volumeMounts[?(@.name==\"$volname\")].mountPath}" 2>/dev/null || true)
  if [[ -n "$m1" && -n "$m2" && -n "$m3" ]]; then
    pass "all three containers mount the same volume ($m1, $m2, $m3)"
  else
    fail "not all containers mount the shared volume"
  fi
else
  fail "could not inspect container volume mounts"
fi

fieldref=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath="{.spec.containers[$c1_idx].env[?(@.name==\"MY_NODE_NAME\")].valueFrom.fieldRef.fieldPath}" 2>/dev/null || true)
check_eq "c1 MY_NODE_NAME uses fieldRef spec.nodeName" "$fieldref" "spec.nodeName"

node=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
actual_node=$(kubectl -n "$NS" exec "$POD" -c c1 -- printenv MY_NODE_NAME 2>/dev/null || true)
check_eq "c1 sees the node name in MY_NODE_NAME" "$actual_node" "$node"

cmd2=$(kubectl -n "$NS" get pod "$POD" -o jsonpath="{.spec.containers[$c2_idx].command[*]}" 2>/dev/null || true)
check_contains "c2 writes date to date.log" "$cmd2" "date >>"
check_contains "c2 loops with sleep" "$cmd2" "sleep 1"

cmd3=$(kubectl -n "$NS" get pod "$POD" -o jsonpath="{.spec.containers[$c3_idx].command[*]}" 2>/dev/null || true)
check_contains "c3 tails the log" "$cmd3" "tail -f"

if [[ -n "${m2:-}" ]]; then
  lines=$(kubectl -n "$NS" exec "$POD" -c c2 -- sh -c "wc -l < ${m2}/date.log" 2>/dev/null | tr -d ' ' || true)
  if [[ "${lines:-0}" -ge 1 ]]; then
    pass "date.log is being written (${lines} lines)"
  else
    fail "date.log is empty"
  fi
fi

logs=""
for _ in $(seq 1 30); do
  logs=$(kubectl -n "$NS" logs "$POD" -c c3 2>/dev/null || true)
  grep -Eq '[A-Z][a-z]{2} .* [0-9]{4}' <<<"$logs" && break
  sleep 2
done
if grep -Eq '[A-Z][a-z]{2} .* [0-9]{4}' <<<"$logs"; then
  pass "c3 logs show streamed timestamps"
else
  fail "c3 logs do not show timestamps"
fi

ready=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.status.conditions[?(@.type=="ContainersReady")].status}' 2>/dev/null || true)
check_eq "all containers are Ready" "$ready" "True"

summary
