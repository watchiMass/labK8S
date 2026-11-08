#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=a9-api
POD=api-caller
SA="system:serviceaccount:a9-api:pod-reader"
info "Validating RBAC, projected token and API calls..."

bind=$(kubectl -n "$NS" get rolebinding pod-reader-binding \
  -o jsonpath='{.roleRef.kind}/{.roleRef.name}/{.subjects[0].name}' 2>/dev/null || true)
check_eq "RoleBinding pod-reader-binding -> Role pod-reader -> SA pod-reader" \
  "$bind" "Role/pod-reader/pod-reader"

check_eq "SA can list Pods in a9-api" \
  "$(kubectl auth can-i list pods -n "$NS" --as="$SA" 2>/dev/null || true)" "yes"
check_eq "SA cannot list Pods in default" \
  "$(kubectl auth can-i list pods -n default --as="$SA" 2>/dev/null || true)" "no"

status=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "Pod $POD is Running" "$status" "Running"

sa=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null || true)
check_eq "Pod uses ServiceAccount pod-reader" "$sa" "pod-reader"

exp=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.volumes[?(@.name=="api-token")].projected.sources[0].serviceAccountToken.expirationSeconds}' 2>/dev/null || true)
check_eq "projected token expires in 600 seconds" "$exp" "600"

token_path=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.volumes[?(@.name=="api-token")].projected.sources[0].serviceAccountToken.path}' 2>/dev/null || true)
check_eq "projected token path is token" "$token_path" "token"

mount=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="api-token")].mountPath}' 2>/dev/null || true)
check_eq "api-token volume is mounted at /var/run/secrets/custom" "$mount" "/var/run/secrets/custom"

if timeout 20 kubectl -n "$NS" exec "$POD" -- test -s /var/run/secrets/custom/token >/dev/null 2>&1; then
  pass "projected token file exists inside the Pod"
else
  fail "projected token file is missing inside the Pod"
fi

api_code() {
  local namespace="$1"
  timeout 25 kubectl -n "$NS" exec "$POD" -- sh -c "
    TOKEN=\$(cat /var/run/secrets/custom/token)
    curl -s -o /dev/null -w '%{http_code}' \
      --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
      -H \"Authorization: Bearer \$TOKEN\" \
      https://kubernetes.default.svc/api/v1/namespaces/${namespace}/pods
  " 2>/dev/null || true
}

check_eq "API call with the token lists Pods in a9-api (HTTP 200)" \
  "$(api_code a9-api)" "200"
check_eq "API call with the token is forbidden in default (HTTP 403)" \
  "$(api_code default)" "403"

summary
