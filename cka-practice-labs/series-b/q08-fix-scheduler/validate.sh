#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
info "Validating scheduler repair..."
MANIFEST=/etc/kubernetes/manifests/kube-scheduler.yaml

if $SUDO test -s "$MANIFEST"; then
  pass "scheduler manifest exists"
else
  fail "scheduler manifest is missing"
fi

if $SUDO grep -q 'this-flag-was-injected' "$MANIFEST" 2>/dev/null; then
  fail "the invalid flag is still present in the manifest"
else
  pass "the invalid flag has been removed"
fi

if [[ -n "$($SUDO grep -E -- '- kube-scheduler' "$MANIFEST" 2>/dev/null)" ]]; then
  pass "the kube-scheduler command line is still present"
else
  fail "the kube-scheduler command line is missing from the manifest"
fi

for _ in $(seq 1 45); do
  sched=$(kubectl -n kube-system get pods -l component=kube-scheduler \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
  ready=$(kubectl -n kube-system get pods -l component=kube-scheduler \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || true)
  [[ "$sched" == "Running" && "$ready" == "true" ]] && break
  sleep 2
done
check_eq "kube-scheduler static Pod is Running" "$sched" "Running"
check_eq "kube-scheduler container is Ready" "$ready" "true"

kubectl delete pod scheduler-probe -n default --ignore-not-found >/dev/null 2>&1 || true
kubectl run scheduler-probe -n default --image=nginx:1-alpine --restart=Never >/dev/null 2>&1 || true

for _ in $(seq 1 60); do
  phase=$(kubectl get pod scheduler-probe -n default -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "$phase" == "Running" ]] && break
  sleep 2
done
check_eq "a newly created Pod is scheduled and Running" "$phase" "Running"

node=$(kubectl get pod scheduler-probe -n default -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
if [[ -n "$node" ]]; then
  pass "scheduler-probe was assigned to node $node"
else
  fail "scheduler-probe has no nodeName"
fi

kubectl delete pod scheduler-probe -n default --ignore-not-found >/dev/null 2>&1 || true
summary
