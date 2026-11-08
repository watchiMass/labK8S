#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=b13-ds
info "Validating DaemonSet coverage..."

if kubectl -n "$NS" get daemonset node-agent >/dev/null 2>&1; then
  pass "DaemonSet node-agent exists"
else
  fail "DaemonSet node-agent is missing"
  summary
fi

NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
for _ in $(seq 1 90); do
  desired=$(kubectl -n "$NS" get daemonset node-agent -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || true)
  ready=$(kubectl -n "$NS" get daemonset node-agent -o jsonpath='{.status.numberReady}' 2>/dev/null || true)
  updated=$(kubectl -n "$NS" get daemonset node-agent -o jsonpath='{.status.updatedNumberScheduled}' 2>/dev/null || true)
  [[ "$desired" == "$NODES" && "$ready" == "$NODES" && "$updated" == "$NODES" ]] && break
  sleep 2
done

check_eq "desired Pods equals node count" "$desired" "$NODES"
check_eq "ready Pods equals node count" "$ready" "$NODES"
check_eq "updated Pods equals node count" "$updated" "$NODES"

pods=$(kubectl -n "$NS" get pods -l app=node-agent -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null || true)
node_count=$(tr ' ' '\n' <<<"$pods" | grep -c . || true)
check_eq "one node-agent Pod per node" "$node_count" "$NODES"

CP=$(controlplane_node)
if [[ -n "$CP" ]] && tr ' ' '\n' <<<"$pods" | grep -qx "$CP"; then
  pass "a node-agent Pod runs on the control-plane node $CP"
else
  fail "no node-agent Pod runs on the control-plane node '$CP'"
fi

image=$(kubectl -n "$NS" get daemonset node-agent \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "image is busybox:1.36" "$image" "busybox:1.36"

cpu=$(kubectl -n "$NS" get daemonset node-agent \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
mem=$(kubectl -n "$NS" get daemonset node-agent \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || true)
check_eq "CPU request is 10m" "$cpu" "10m"
check_eq "memory request is 16Mi" "$mem" "16Mi"

cp_taints=$(kubectl get node "$CP" -o jsonpath='{range .spec.taints[*]}{.key}/{.effect}{"\n"}{end}' 2>/dev/null || true)
if [[ -n "$CP" ]] && grep -q 'NoSchedule' <<<"$cp_taints"; then
  tols=$(kubectl -n "$NS" get daemonset node-agent \
    -o jsonpath='{range .spec.template.spec.tolerations[*]}{.key}/{.operator}/{.effect}{"\n"}{end}' 2>/dev/null || true)
  if grep -Eq '^/(|.*)/Exists/.*$' <<<"$tols" || grep -Eq 'control-plane|master' <<<"$tols"; then
    pass "DaemonSet tolerates the control-plane taint"
  else
    fail "DaemonSet does not tolerate the control-plane taint (got: $tols)"
  fi
else
  pass "control-plane node is not tainted with NoSchedule"
fi

summary
