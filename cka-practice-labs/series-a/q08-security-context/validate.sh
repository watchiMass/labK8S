#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=a8-sec
POD=secure-sleeper
info "Validating hardened Pod..."

phase=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "Pod $POD is Running" "$phase" "Running"

check_eq "runAsUser is 1000" \
  "$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.securityContext.runAsUser}' 2>/dev/null || true)" "1000"
check_eq "runAsGroup is 3000" \
  "$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.securityContext.runAsGroup}' 2>/dev/null || true)" "3000"
check_eq "fsGroup is 3000" \
  "$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.securityContext.fsGroup}' 2>/dev/null || true)" "3000"
check_eq "seccomp profile is RuntimeDefault" \
  "$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.securityContext.seccompProfile.type}' 2>/dev/null || true)" "RuntimeDefault"

check_eq "allowPrivilegeEscalation is false" \
  "$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null || true)" "false"
check_eq "readOnlyRootFilesystem is true" \
  "$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null || true)" "true"
drop=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[*]}' 2>/dev/null || true)
check_contains "all capabilities are dropped" "$drop" "ALL"

voltype=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.volumes[0].emptyDir}' 2>/dev/null || true)
if [[ -n "$voltype" || "$voltype" == "{}" ]]; then
  pass "Pod uses an emptyDir volume"
else
  fail "Pod does not use an emptyDir volume (volume[0] is not emptyDir)"
fi

mountpath=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.containers[0].volumeMounts[0].mountPath}' 2>/dev/null || true)
check_eq "emptyDir is mounted at /tmp" "$mountpath" "/tmp"

if timeout 10 kubectl -n "$NS" exec "$POD" -- touch /tmp/write-probe >/dev/null 2>&1; then
  pass "/tmp is writable"
else
  fail "/tmp is not writable"
fi

if timeout 10 kubectl -n "$NS" exec "$POD" -- touch /root-write-probe >/dev/null 2>&1; then
  fail "container root filesystem is still writable"
else
  pass "container root filesystem is read-only"
fi

summary
