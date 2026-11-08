#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c11-sts
info "Validating StatefulSet, headless Service, PVCs and DNS..."

svc_ip=$(kubectl -n "$NS" get service db-headless -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
check_eq "Service db-headless is headless (clusterIP None)" "$svc_ip" "None"

svc_sel=$(kubectl -n "$NS" get service db-headless -o jsonpath='{.spec.selector.app}' 2>/dev/null || true)
check_eq "Service selects app=db" "$svc_sel" "db"

if kubectl -n "$NS" get statefulset db >/dev/null 2>&1; then
  pass "StatefulSet db exists"
else
  fail "StatefulSet db is missing"
  summary
fi

replicas=$(kubectl -n "$NS" get statefulset db -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
check_eq "StatefulSet has 3 replicas" "$replicas" "3"

service_name=$(kubectl -n "$NS" get statefulset db -o jsonpath='{.spec.serviceName}' 2>/dev/null || true)
check_eq "StatefulSet serviceName is db-headless" "$service_name" "db-headless"

image=$(kubectl -n "$NS" get statefulset db \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "StatefulSet image is nginx:1-alpine" "$image" "nginx:1-alpine"

vct_size=$(kubectl -n "$NS" get statefulset db \
  -o jsonpath='{.spec.volumeClaimTemplates[0].spec.resources.requests.storage}' 2>/dev/null || true)
vct_name=$(kubectl -n "$NS" get statefulset db \
  -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' 2>/dev/null || true)
vct_sc=$(kubectl -n "$NS" get statefulset db \
  -o jsonpath='{.spec.volumeClaimTemplates[0].spec.storageClassName}' 2>/dev/null || true)
check_eq "volumeClaimTemplate is named data" "$vct_name" "data"
check_eq "volumeClaimTemplate requests 20Mi" "$vct_size" "20Mi"
check_eq "volumeClaimTemplate uses local-path" "$vct_sc" "local-path"

mount=$(kubectl -n "$NS" get statefulset db \
  -o jsonpath='{range .spec.template.spec.containers[0].volumeMounts[*]}{.name}:{.mountPath}{"\n"}{end}' 2>/dev/null || true)
if grep -qx 'data:/data' <<<"$mount"; then
  pass "template mounts the data volume at /data"
else
  fail "template does not mount the data volume at /data (got '$mount')"
fi

for _ in $(seq 1 90); do
  ready=$(kubectl -n "$NS" get pods -l app=db \
    -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o 'True' | wc -l | tr -d ' ')
  [[ "$ready" == "3" ]] && break
  sleep 2
done
check_eq "3 db Pods are Ready" "$ready" "3"

for i in 0 1 2; do
  phase=$(kubectl -n "$NS" get pod "db-$i" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  check_eq "Pod db-$i is Running" "$phase" "Running"
  pvc_phase=$(kubectl -n "$NS" get pvc "data-db-$i" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  check_eq "PVC data-db-$i is Bound" "$pvc_phase" "Bound"
done

pod1_ip=$(kubectl -n "$NS" get pod db-1 -o jsonpath='{.status.podIP}' 2>/dev/null || true)
DOMAIN=$(cluster_domain "$NS" db-0)
fqdn="db-1.db-headless.$NS.svc.$DOMAIN"
out=$(kubectl -n "$NS" exec db-0 -- nslookup "$fqdn" 2>/dev/null || true)
if grep -qi 'Name:' <<<"$out" && [[ -n "$pod1_ip" ]] && grep -Fq "$pod1_ip" <<<"$out"; then
  pass "$fqdn resolves to db-1 ($pod1_ip)"
else
  fail "$fqdn does not resolve to db-1 ($pod1_ip)"
fi

summary
