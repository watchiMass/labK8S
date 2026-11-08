#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$SCRIPT_DIR"
info "Validating kubelet, node readiness and workload..."

state=$($SUDO systemctl is-active kubelet 2>/dev/null || true)
check_eq "kubelet service is active" "$state" "active"

NODE=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null \
  | awk -v h="$(hostname)" 'tolower($0)==tolower(h){print; exit}')
if [[ -z "$NODE" ]]; then
  NODE=$(controlplane_node)
fi
if [[ -z "$NODE" ]]; then
  fail "could not determine this node's name"
else
  ready=$(kubectl get node "$NODE" \
    -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{"\n"}{end}' 2>/dev/null || true)
  check_eq "node $NODE is Ready" "$ready" "True"
fi

cfg=$($SUDO grep -E '^[[:space:]]*clientCAFile:' /var/lib/kubelet/config.yaml 2>/dev/null | head -n1 || true)
if [[ -n "$cfg" && "$cfg" != *"cka-broken"* ]]; then
  pass "kubelet clientCAFile points at a real file"
else
  fail "kubelet clientCAFile is still broken (got '$cfg')"
fi

phase=$(kubectl get pod success -n default -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "Pod success is Running" "$phase" "Running"

summary
