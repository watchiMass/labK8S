#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=d11-migrate
info "Validating Deployment selector migration and Service continuity..."

if kubectl -n "$NS" get deployment api >/dev/null 2>&1; then
  fail "old Deployment api still exists"
else
  pass "old Deployment api has been removed"
fi

if kubectl -n "$NS" get deployment api-v2 >/dev/null 2>&1; then
  pass "new Deployment api-v2 exists"
else
  fail "Deployment api-v2 is missing"
  summary
fi

selector=$(kubectl -n "$NS" get deployment api-v2 \
  -o jsonpath='{.spec.selector.matchLabels.app\.kubernetes\.io/name}' 2>/dev/null || true)
check_eq "api-v2 selector is app.kubernetes.io/name=api-v2" "$selector" "api-v2"

template_app=$(kubectl -n "$NS" get deployment api-v2 \
  -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null || true)
template_name=$(kubectl -n "$NS" get deployment api-v2 \
  -o jsonpath='{.spec.template.metadata.labels.app\.kubernetes\.io/name}' 2>/dev/null || true)
check_eq "Pod template keeps app=api for the Service" "$template_app" "api"
check_eq "Pod template has app.kubernetes.io/name=api-v2" "$template_name" "api-v2"

image=$(kubectl -n "$NS" get deployment api-v2 \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "api-v2 image is nginx:1.27-alpine" "$image" "nginx:1.27-alpine"

replicas=$(kubectl -n "$NS" get deployment api-v2 -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
check_eq "api-v2 has 2 replicas" "$replicas" "2"

if kubectl -n "$NS" rollout status deployment/api-v2 --timeout=10s >/dev/null 2>&1; then
  pass "Deployment api-v2 is fully rolled out"
else
  fail "Deployment api-v2 is not fully rolled out"
fi

service_selector=$(kubectl -n "$NS" get service api -o jsonpath='{.spec.selector.app}' 2>/dev/null || true)
check_eq "Service api selector is still app=api" "$service_selector" "api"

pod_labels=$(kubectl -n "$NS" get pods -l app.kubernetes.io/name=api-v2 \
  -o jsonpath='{range .items[*]}{.metadata.labels.app}{"\n"}{end}' 2>/dev/null || true)
app_count=$(printf '%s\n' "$pod_labels" | grep -c '^api$' || true)
check_eq "both api-v2 Pods also carry app=api" "$app_count" "2"

ep_ips=$(kubectl -n "$NS" get endpoints api \
  -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | grep -c . || true)
check_eq "Service api has 2 Endpoints" "$ep_ips" "2"

pod_ips=$(kubectl -n "$NS" get pods -l app.kubernetes.io/name=api-v2 \
  -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort)
ep_sorted=$(kubectl -n "$NS" get endpoints api \
  -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | sort)
if [[ -n "$pod_ips" && "$pod_ips" == "$ep_sorted" ]]; then
  pass "Service Endpoints are exactly the api-v2 Pods"
else
  fail "Service Endpoints do not match the api-v2 Pod IPs"
fi

summary
