#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c5-config
info "Validating ConfigMap update, hot reload and immutability..."

theme=$(kubectl -n "$NS" get configmap app-config -o jsonpath='{.data.theme}' 2>/dev/null || true)
version=$(kubectl -n "$NS" get configmap app-config -o jsonpath='{.data.version}' 2>/dev/null || true)
check_eq "ConfigMap theme is dark" "$theme" "dark"
check_eq "ConfigMap version is still 1" "$version" "1"

pod=$(kubectl -n "$NS" get pods -l app=config-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$pod" ]]; then
  fail "config-app Pod not found"
  summary
fi
pass "config-app Pod: $pod"

file_theme=""
for _ in $(seq 1 90); do
  file_theme=$(kubectl -n "$NS" exec "$pod" -- cat /etc/app-config/theme 2>/dev/null || true)
  [[ "$file_theme" == "dark" ]] && break
  sleep 2
done
check_eq "the mounted theme file hot-reloaded to dark" "$file_theme" "dark"

restarts=$(kubectl -n "$NS" get pod "$pod" \
  -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || true)
check_eq "the Pod container was not restarted" "${restarts:-0}" "0"

pod_created=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || true)
cm_updated=$(kubectl -n "$NS" get configmap app-config \
  -o jsonpath='{range .metadata.managedFields[*]}{.time}{"\n"}{end}' 2>/dev/null | sort | tail -n1 || true)
if [[ -n "$pod_created" && -n "$cm_updated" ]]; then
  pod_epoch=$(date -d "$pod_created" +%s 2>/dev/null || echo 0)
  cm_epoch=$(date -d "$cm_updated" +%s 2>/dev/null || echo 0)
  if [[ "$pod_epoch" -lt "$cm_epoch" ]]; then
    pass "the Pod predates the ConfigMap update (no recreate)"
  else
    fail "the Pod was created/recreated after the ConfigMap update"
  fi
else
  warn "Could not compare timestamps; relying on restartCount/file checks."
fi

if kubectl -n "$NS" get configmap locked-config >/dev/null 2>&1; then
  pass "ConfigMap locked-config exists"
  immutable=$(kubectl -n "$NS" get configmap locked-config -o jsonpath='{.immutable}' 2>/dev/null || true)
  check_eq "locked-config is immutable" "$immutable" "true"
  if kubectl -n "$NS" patch configmap locked-config --type merge \
       -p '{"data":{"probe":"value"}}' >/dev/null 2>&1; then
    fail "locked-config accepted an update despite being immutable"
  else
    pass "API server rejects updates to locked-config"
  fi
else
  fail "ConfigMap locked-config is missing"
fi

summary
