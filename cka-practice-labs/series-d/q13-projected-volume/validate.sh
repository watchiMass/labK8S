#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=d13-projected
POD=projected-app
info "Validating projected volume sources, contents and modes..."

phase=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "Pod is Running" "$phase" "Running"

team=$(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.metadata.labels.team}' 2>/dev/null || true)
check_eq "Pod has label team=platform" "$team" "platform"

sources=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.volumes[?(@.name=="bundle")].projected.sources}' 2>/dev/null || true)
if [[ -n "$sources" ]]; then
  pass "projected volume bundle exists"
else
  fail "projected volume bundle is missing"
fi
check_contains "projected volume includes ConfigMap app-config" "$sources" "app-config"
check_contains "projected volume includes Secret app-secret" "$sources" "app-secret"
check_contains "projected volume includes a downwardAPI source" "$sources" "downwardAPI"

mount=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="bundle")].mountPath}' 2>/dev/null || true)
readonly=$(kubectl -n "$NS" get pod "$POD" \
  -o jsonpath='{.spec.containers[0].volumeMounts[?(@.name=="bundle")].readOnly}' 2>/dev/null || true)
check_eq "bundle is mounted at /etc/bundle" "$mount" "/etc/bundle"
check_eq "bundle mount is read-only" "$readonly" "true"

props=$(kubectl -n "$NS" exec "$POD" -- cat /etc/bundle/config/app.properties 2>/dev/null || true)
props_trim=$(sed -e 's/[[:space:]]*$//' <<<"$props")
if [[ "$props_trim" == "mode=prod
timeout=5" ]]; then
  pass "config/app.properties content is correct"
else
  fail "config/app.properties content is wrong (got '$props_trim')"
fi

password=$(kubectl -n "$NS" exec "$POD" -- cat /etc/bundle/secrets/password 2>/dev/null || true)
check_eq "secrets/password content is correct" "$(tr -d '\r\n' <<<"$password")" "secret-projected"

podname=$(kubectl -n "$NS" exec "$POD" -- cat /etc/bundle/meta/pod-name 2>/dev/null || true)
check_eq "meta/pod-name content is correct" "$(tr -d '\r\n' <<<"$podname")" "$POD"

teamfile=$(kubectl -n "$NS" exec "$POD" -- cat /etc/bundle/meta/team 2>/dev/null || true)
check_eq "meta/team content is correct" "$(tr -d '\r\n' <<<"$teamfile")" "platform"

mode_of() { # path
  kubectl -n "$NS" exec "$POD" -- stat -c '%a' "$1" 2>/dev/null | tr -d '\r\n'
}
check_eq "config/app.properties mode is 640" "$(mode_of /etc/bundle/config/app.properties)" "640"
check_eq "secrets/password mode is 400" "$(mode_of /etc/bundle/secrets/password)" "400"
check_eq "meta/pod-name mode is 644" "$(mode_of /etc/bundle/meta/pod-name)" "644"
check_eq "meta/team mode is 644" "$(mode_of /etc/bundle/meta/team)" "644"

summary
