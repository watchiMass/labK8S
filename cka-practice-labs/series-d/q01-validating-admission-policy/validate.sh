#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
info "Validating ValidatingAdmissionPolicy and CEL behaviour..."

if kubectl get validatingadmissionpolicy d01-pod-rules >/dev/null 2>&1; then
  pass "ValidatingAdmissionPolicy d01-pod-rules exists"
else
  fail "ValidatingAdmissionPolicy d01-pod-rules is missing"
  summary
fi

if kubectl get validatingadmissionpolicybinding d01-pod-rules-binding >/dev/null 2>&1; then
  pass "ValidatingAdmissionPolicyBinding exists"
else
  fail "ValidatingAdmissionPolicyBinding is missing"
  summary
fi

policy_name=$(kubectl get validatingadmissionpolicybinding d01-pod-rules-binding \
  -o jsonpath='{.spec.policyName}' 2>/dev/null || true)
check_eq "binding references d01-pod-rules" "$policy_name" "d01-pod-rules"

actions=$(kubectl get validatingadmissionpolicybinding d01-pod-rules-binding \
  -o jsonpath='{.spec.validationActions[*]}' 2>/dev/null || true)
check_contains "binding uses Deny" "$actions" "Deny"

# 1. Invalid Pod in the guarded namespace must be rejected.
if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: d01-invalid
  namespace: d01-policy
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "60"]
YAML
then
  fail "a Pod without cost-center label or limits was admitted in d01-policy"
else
  pass "a Pod without cost-center label or limits is rejected in d01-policy"
fi

# 2. tier=prod with limits but no requests must be rejected.
if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: d01-prod
  namespace: d01-policy
  labels:
    cost-center: "42"
    tier: prod
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "60"]
      resources:
        limits:
          cpu: 100m
          memory: 64Mi
YAML
then
  fail "a tier=prod Pod with no requests was admitted"
else
  pass "a tier=prod Pod without requests is rejected"
fi

# 2b. tier=prod with requests different from limits must be rejected.
if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: d01-prod-mismatch
  namespace: d01-policy
  labels:
    cost-center: "42"
    tier: prod
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "60"]
      resources:
        requests:
          cpu: 50m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 64Mi
YAML
then
  fail "a tier=prod Pod with requests != limits was admitted"
else
  pass "a tier=prod Pod with requests != limits is rejected"
fi

# 2c. Compliant prod Pod (requests == limits) must be admitted.
if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: d01-prod-valid
  namespace: d01-policy
  labels:
    cost-center: "42"
    tier: prod
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "60"]
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 64Mi
YAML
then
  pass "a compliant tier=prod Pod is admitted"
else
  fail "a compliant tier=prod Pod is wrongly rejected"
fi

# 3. Compliant Pod must be admitted.
if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: d01-valid
  namespace: d01-policy
  labels:
    cost-center: "42"
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "60"]
      resources:
        limits:
          cpu: 100m
          memory: 64Mi
YAML
then
  pass "a compliant Pod is admitted in d01-policy"
else
  fail "a compliant Pod is wrongly rejected in d01-policy"
fi

# 4. Policy scope must not leak to other namespaces.
if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: d01-default
  namespace: default
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sleep", "60"]
YAML
then
  pass "the policy does not affect namespace default"
else
  fail "the policy also blocks Pods outside d01-policy"
fi

summary
