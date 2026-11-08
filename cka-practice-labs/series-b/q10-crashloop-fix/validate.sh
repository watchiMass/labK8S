#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=b10-crash
info "Validating the payment-api workload..."

if kubectl -n "$NS" rollout status deployment/payment-api --timeout=10s >/dev/null 2>&1; then
  pass "Deployment payment-api is fully rolled out"
else
  fail "Deployment payment-api is not fully rolled out"
fi

phase=$(kubectl -n "$NS" get pods -l app=payment-api -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
check_eq "payment-api Pod is Running" "$phase" "Running"

env_mode=$(kubectl -n "$NS" get deployment payment-api \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_MODE")].value}' 2>/dev/null || true)
check_eq "APP_MODE is prod" "$env_mode" "prod"

image=$(kubectl -n "$NS" get deployment payment-api \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "container image is unchanged" "$image" "busybox:1.36"

cmd=$(kubectl -n "$NS" get deployment payment-api \
  -o jsonpath='{.spec.template.spec.containers[0].command[*]}' 2>/dev/null || true)
check_contains "container command still checks APP_MODE" "$cmd" "APP_MODE"

ready=$(kubectl -n "$NS" get pods -l app=payment-api \
  -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
check_contains "payment-api Pod is Ready" "$ready" "True"

summary
