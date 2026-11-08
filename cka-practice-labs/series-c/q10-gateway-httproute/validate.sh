#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_cmd python3 "Install python3 to validate the HTTPRoute structure."
NS=project-r500
info "Validating Gateway and HTTPRoute configuration..."

if kubectl -n "$NS" get gateway r500-gateway >/dev/null 2>&1; then
  pass "Gateway r500-gateway exists"
else
  fail "Gateway r500-gateway is missing; re-run setup.sh"
fi

listener=$(kubectl -n "$NS" get gateway r500-gateway \
  -o jsonpath='{.spec.listeners[0].port}/{.spec.listeners[0].protocol}' 2>/dev/null || true)
check_eq "Gateway has an HTTP listener on port 80" "$listener" "80/HTTP"

if kubectl -n "$NS" get httproute traffic-director >/dev/null 2>&1; then
  pass "HTTPRoute traffic-director exists"
else
  fail "HTTPRoute traffic-director is missing"
  summary
fi

checker=$(mktemp)
cat >"$checker" <<'PY'
import json
import sys

route = json.load(sys.stdin)
spec = route.get("spec", {})
rules = spec.get("rules", [])
errors = []

parents = [p.get("name") for p in spec.get("parentRefs", [])]
if "r500-gateway" not in parents:
    errors.append("parentRefs does not include r500-gateway")

def path_of(match):
    path = match.get("path") or {}
    return path.get("type", "PathPrefix"), path.get("value")

def has_mobile_header(match):
    for h in match.get("headers") or []:
        if (h.get("name") == "User-Agent" and h.get("type") == "Exact"
                and h.get("value") == "mobile"):
            return True
    return False

def backends(rule):
    result = []
    for b in rule.get("backendRefs") or []:
        result.append((b.get("name"), str(b.get("port", 80))))
    return result

def has_rule(path, backend, header_required=None):
    for rule in rules:
        matches = rule.get("matches") or []
        if not matches:
            continue
        path_ok = any(path_of(m)[0] == "PathPrefix" and path_of(m)[1] == path
                      for m in matches)
        if not path_ok:
            continue
        header_present = any(has_mobile_header(m) for m in matches)
        if header_required is True and not header_present:
            continue
        if header_required is False and header_present:
            continue
        if backend in backends(rule):
            return True
    return False

if not has_rule("/desktop", ("desktop", "80")):
    errors.append("/desktop does not route to desktop:80")
if not has_rule("/mobile", ("mobile", "80")):
    errors.append("/mobile does not route to mobile:80")
if not has_rule("/auto", ("mobile", "80"), header_required=True):
    errors.append("no /auto + User-Agent Exact mobile rule to mobile:80")
if not has_rule("/auto", ("desktop", "80"), header_required=False):
    errors.append("no header-less /auto fallback rule to desktop:80")

if errors:
    for error in errors:
        print(error)
    sys.exit(1)
print("HTTPRoute rules are correct")
PY

route_json=$(kubectl -n "$NS" get httproute traffic-director -o json 2>/dev/null || true)
if result=$(printf '%s' "$route_json" | python3 "$checker" 2>&1); then
  pass "$result"
else
  fail "$result"
fi
rm -f "$checker"

for svc in desktop mobile; do
  port=$(kubectl -n "$NS" get service "$svc" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)
  check_eq "Service $svc still exposes port 80" "$port" "80"
done

summary
