#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c12-spread
info "Validating topology spread constraints and Pod placement..."

if kubectl -n "$NS" get deployment deploy-important >/dev/null 2>&1; then
  pass "Deployment deploy-important exists"
else
  fail "Deployment deploy-important is missing"
  summary
fi

replicas=$(kubectl -n "$NS" get deployment deploy-important -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
check_eq "Deployment has 3 replicas" "$replicas" "3"

labels=$(kubectl -n "$NS" get deployment deploy-important \
  -o jsonpath='{.metadata.labels.id}/{.spec.template.metadata.labels.id}' 2>/dev/null || true)
check_eq "Deployment and Pod template both have id=very-important" \
  "$labels" "very-important/very-important"

c1_image=$(kubectl -n "$NS" get deployment deploy-important \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="container1")].image}' 2>/dev/null || true)
c2_image=$(kubectl -n "$NS" get deployment deploy-important \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="container2")].image}' 2>/dev/null || true)
check_eq "container1 uses nginx:1-alpine" "$c1_image" "nginx:1-alpine"
check_eq "container2 uses registry.k8s.io/pause:3.10" "$c2_image" "registry.k8s.io/pause:3.10"

skew=$(kubectl -n "$NS" get deployment deploy-important \
  -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].maxSkew}' 2>/dev/null || true)
topo=$(kubectl -n "$NS" get deployment deploy-important \
  -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].topologyKey}' 2>/dev/null || true)
when=$(kubectl -n "$NS" get deployment deploy-important \
  -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].whenUnsatisfiable}' 2>/dev/null || true)
sel=$(kubectl -n "$NS" get deployment deploy-important \
  -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].labelSelector.matchLabels.id}' 2>/dev/null || true)
check_eq "maxSkew is 1" "$skew" "1"
check_eq "topologyKey is kubernetes.io/hostname" "$topo" "kubernetes.io/hostname"
check_eq "whenUnsatisfiable is DoNotSchedule" "$when" "DoNotSchedule"
check_eq "constraint selects id=very-important" "$sel" "very-important"

eligible=0
while IFS='|' read -r name effects; do
  [[ -z "$name" ]] && continue
  case ",$effects" in
    *",NoSchedule"*) continue ;;
  esac
  eligible=$((eligible + 1))
done < <(kubectl get nodes \
  -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{range .spec.taints[*]}{.effect}{","}{end}{"\n"}{end}' 2>/dev/null)

expected_running=3
[[ "$eligible" -lt 3 ]] && expected_running="$eligible"

for _ in $(seq 1 90); do
  running=$(kubectl -n "$NS" get pods -l id=very-important \
    -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | grep -c '^Running$' || true)
  [[ "$running" == "$expected_running" ]] && break
  sleep 2
done
check_eq "running Pods equals min(3, schedulable nodes)" "$running" "$expected_running"

nodes=$(kubectl -n "$NS" get pods -l id=very-important \
  -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null || true)
uniq=$(printf '%s\n' "$nodes" | grep -c . || true)
distinct=$(printf '%s\n' "$nodes" | sort -u | grep -c . || true)
if [[ "$uniq" -eq "$distinct" ]]; then
  pass "every running Pod is on a distinct node"
else
  fail "two running Pods share a node"
fi

total_pods=$(kubectl -n "$NS" get pods -l id=very-important --no-headers 2>/dev/null | wc -l | tr -d ' ')
check_eq "Deployment created 3 Pods in total" "$total_pods" "3"

pending=$(kubectl -n "$NS" get pods -l id=very-important \
  -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | grep -c '^Pending$' || true)
expected_pending=$((3 - expected_running))
check_eq "overflow Pods stay Pending" "$pending" "$expected_pending"

summary
