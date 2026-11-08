#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=d03-sts
info "Validating partitioned StatefulSet rollout..."

strategy=$(kubectl -n "$NS" get statefulset store \
  -o jsonpath='{.spec.updateStrategy.type}' 2>/dev/null || true)
check_eq "StatefulSet update strategy is RollingUpdate" "$strategy" "RollingUpdate"

partition=$(kubectl -n "$NS" get statefulset store \
  -o jsonpath='{.spec.updateStrategy.rollingUpdate.partition}' 2>/dev/null || true)
check_eq "rolling update partition is 1" "$partition" "1"

template_image=$(kubectl -n "$NS" get statefulset store \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "StatefulSet template uses nginx:1.27-alpine" "$template_image" "nginx:1.27-alpine"

svc_ip=$(kubectl -n "$NS" get service store-headless -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
check_eq "Service store-headless is still headless" "$svc_ip" "None"

for _ in $(seq 1 120); do
  img0=$(kubectl -n "$NS" get pod store-0 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)
  img1=$(kubectl -n "$NS" get pod store-1 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)
  img2=$(kubectl -n "$NS" get pod store-2 -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)
  ready=$(kubectl -n "$NS" get pods -l app=store \
    -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o 'True' | wc -l | tr -d ' ')
  if [[ "$img0" == "nginx:1-alpine" && "$img1" == "nginx:1.27-alpine" \
        && "$img2" == "nginx:1.27-alpine" && "$ready" == "3" ]]; then
    break
  fi
  sleep 2
done

check_eq "store-0 still runs nginx:1-alpine" "$img0" "nginx:1-alpine"
check_eq "store-1 runs nginx:1.27-alpine" "$img1" "nginx:1.27-alpine"
check_eq "store-2 runs nginx:1.27-alpine" "$img2" "nginx:1.27-alpine"
check_eq "all three StatefulSet Pods are Ready" "$ready" "3"

for i in 0 1 2; do
  phase=$(kubectl -n "$NS" get pod "store-$i" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  check_eq "store-$i is Running" "$phase" "Running"
done

summary
