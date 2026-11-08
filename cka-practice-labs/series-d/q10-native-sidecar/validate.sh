#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=d10-sidecar
POD=native-sidecar
info "Validating native sidecar Pod..."

phase=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "Pod is Running" "$phase" "Running"

sidecar_name=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.initContainers[0].name}' 2>/dev/null || true)
sidecar_image=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.initContainers[0].image}' 2>/dev/null || true)
sidecar_policy=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.initContainers[0].restartPolicy}' 2>/dev/null || true)
check_eq "init container is named log-shipper" "$sidecar_name" "log-shipper"
check_eq "log-shipper uses busybox:1.36" "$sidecar_image" "busybox:1.36"
check_eq "log-shipper restartPolicy is Always (native sidecar)" "$sidecar_policy" "Always"

app_image=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.containers[?(@.name=="app")].image}' 2>/dev/null || true)
check_eq "app container uses busybox:1.36" "$app_image" "busybox:1.36"

volume=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.volumes[0].name}' 2>/dev/null || true)
empty=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.volumes[0].emptyDir}' 2>/dev/null || true)
if [[ "$volume" == "logs" && -n "$empty" ]]; then
  pass "shared volume logs is an emptyDir"
else
  fail "shared emptyDir volume 'logs' is missing"
fi

app_mount=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.containers[?(@.name=="app")].volumeMounts[?(@.name=="logs")].mountPath}' 2>/dev/null || true)
side_mount=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.initContainers[0].volumeMounts[?(@.name=="logs")].mountPath}' 2>/dev/null || true)
check_eq "app mounts logs at /var/log" "$app_mount" "/var/log"
check_eq "sidecar mounts logs at /var/log" "$side_mount" "/var/log"

started=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.status.initContainerStatuses[0].started}' 2>/dev/null || true)
check_eq "native sidecar status started is true" "$started" "true"

logs=""
for _ in $(seq 1 40); do
  logs=$(kubectl -n "$NS" logs "$POD" -c log-shipper 2>/dev/null || true)
  grep -q 'tick' <<<"$logs" && break
  sleep 2
done
if grep -q 'tick' <<<"$logs"; then
  pass "log-shipper streams tick lines from the shared volume"
else
  fail "log-shipper logs do not contain tick lines"
fi

ready=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
check_eq "Pod is Ready" "$ready" "True"

summary
