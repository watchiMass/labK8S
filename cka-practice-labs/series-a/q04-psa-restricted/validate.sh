#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
info "Validating Pod Security Admission configuration and workload..."

enforce=$(kubectl get namespace a4-psa -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || true)
check_eq "namespace enforces restricted" "$enforce" "restricted"

version=$(kubectl get namespace a4-psa -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}' 2>/dev/null || true)
check_eq "namespace enforces the latest policy version" "$version" "latest"

if kubectl -n a4-psa rollout status deployment/legacy --timeout=10s >/dev/null 2>&1; then
  pass "Deployment legacy is fully rolled out"
else
  fail "Deployment legacy is not fully rolled out"
fi

pod_sc_runasnonroot=$(kubectl -n a4-psa get deployment legacy \
  -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null || true)
check_eq "Pod template sets runAsNonRoot" "$pod_sc_runasnonroot" "true"

seccomp=$(kubectl -n a4-psa get deployment legacy \
  -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}' 2>/dev/null || true)
check_eq "Pod template uses the RuntimeDefault seccomp profile" "$seccomp" "RuntimeDefault"

ape=$(kubectl -n a4-psa get deployment legacy \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null || true)
check_eq "container disallows privilege escalation" "$ape" "false"

drop=$(kubectl -n a4-psa get deployment legacy \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop[*]}' 2>/dev/null || true)
check_contains "container drops ALL capabilities" "$drop" "ALL"

image=$(kubectl -n a4-psa get deployment legacy \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "legacy container image is unchanged" "$image" "busybox:1.36"

pods_ready=$(kubectl -n a4-psa get pods -l app=legacy -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
check_contains "legacy Pod is Ready" "$pods_ready" "True"

if kubectl -n a4-psa run psa-probe --image=busybox:1.36 --restart=Never -- sleep 5 >/dev/null 2>&1; then
  fail "PSA did not reject a root-running busybox Pod"
  kubectl -n a4-psa delete pod psa-probe --ignore-not-found >/dev/null 2>&1 || true
else
  pass "PSA rejects a non-compliant root-running Pod"
fi

summary
