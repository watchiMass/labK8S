#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=a14-ssa
info "Validating server-side apply result and field ownership..."

replicas=$(kubectl -n "$NS" get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
check_eq "Deployment replicas is 3" "$replicas" "3"

image=$(kubectl -n "$NS" get deployment web \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "image is nginx:1.27-alpine" "$image" "nginx:1.27-alpine"

ann=$(kubectl -n "$NS" get deployment web \
  -o jsonpath='{.metadata.annotations.change-cause}' 2>/dev/null || true)
check_eq "annotation change-cause=scale-up is present" "$ann" "scale-up"

if kubectl -n "$NS" rollout status deployment/web --timeout=10s >/dev/null 2>&1; then
  pass "Deployment web is fully rolled out"
else
  fail "Deployment web is not fully rolled out"
fi

ready=$(kubectl -n "$NS" get pods -l app=web \
  -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
count=$(grep -o 'True' <<<"$ready" | wc -l | tr -d ' ')
check_eq "three web Pods are Ready" "$count" "3"

managers=$(kubectl -n "$NS" get deployment web \
  -o jsonpath='{range .metadata.managedFields[*]}{.manager}{"|"}{.operation}{"\n"}{end}' 2>/dev/null || true)
check_contains "managedFields contains app-team with Apply" "$managers" "app-team|Apply"

fields=$(kubectl -n "$NS" get deployment web \
  -o jsonpath='{range .metadata.managedFields[?(@.manager=="app-team")]}{.fieldsV1}{"\n"}{end}' 2>/dev/null || true)
check_contains "app-team owns the replicas field" "$fields" "replicas"

summary
