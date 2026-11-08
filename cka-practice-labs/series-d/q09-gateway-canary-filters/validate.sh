#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_cmd python3 "python3 is used to inspect the HTTPRoute."
NS=d09-gw
info "Validating HTTPRoute weights, matches and filters..."

if kubectl -n "$NS" get gateway d09-gateway >/dev/null 2>&1; then
  pass "Gateway d09-gateway exists"
else
  fail "Gateway d09-gateway is missing; re-run setup.sh"
fi

listener=$(kubectl -n "$NS" get gateway d09-gateway \
  -o jsonpath='{.spec.listeners[0].port}/{.spec.listeners[0].protocol}' 2>/dev/null || true)
check_eq "Gateway listener is HTTP on port 80" "$listener" "80/HTTP"

if kubectl -n "$NS" get httproute split >/dev/null 2>&1; then
  pass "HTTPRoute split exists"
else
  fail "HTTPRoute split is missing"
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
if "d09-gateway" not in parents:
    errors.append("parentRefs does not include d09-gateway")

def path_of(match):
    path = match.get("path") or {}
    return path.get("type", "PathPrefix"), path.get("value")

def has_header(match, name, value):
    for header in match.get("headers") or []:
        if (header.get("name", "").lower() == name.lower()
                and header.get("type", "Exact") == "Exact"
                and header.get("value") == value):
            return True
    return False

def backends(rule):
    result = {}
    for backend in rule.get("backendRefs") or []:
        if str(backend.get("port", 80)) != "80":
            continue
        result[backend.get("name")] = int(backend.get("weight", 1))
    return result

def filters(rule):
    return rule.get("filters") or []

def filter_of(rule, filter_type):
    return [f for f in filters(rule) if f.get("type") == filter_type]

def has_path(rule, path):
    for match in rule.get("matches") or []:
        match_type, value = path_of(match)
        if match_type == "PathPrefix" and value == path:
            return True
    return False

# Rule 1: weighted split on /.
weighted = False
for rule in rules:
    if not has_path(rule, "/"):
        continue
    weights = backends(rule)
    if weights == {"stable": 90, "canary": 10}:
        weighted = True
if not weighted:
    errors.append("/ does not split stable=90 / canary=10 on port 80")

# Rule 2: /beta + X-Channel beta -> canary with both filters.
beta_rule = None
for rule in rules:
    for match in rule.get("matches") or []:
        match_type, value = path_of(match)
        if match_type == "PathPrefix" and value == "/beta" and has_header(match, "X-Channel", "beta"):
            beta_rule = rule
            break
    if beta_rule:
        break

if beta_rule is None:
    errors.append("no PathPrefix /beta rule with exact X-Channel: beta header")
else:
    if backends(beta_rule).get("canary") != 100:
        errors.append("the /beta rule does not send 100 to canary")
    header_filters = filter_of(beta_rule, "RequestHeaderModifier")
    header_ok = False
    for filt in header_filters:
        for item in (filt.get("requestHeaderModifier") or {}).get("set") or []:
            if item.get("name", "").lower() == "x-env" and item.get("value") == "canary":
                header_ok = True
    if not header_ok:
        errors.append("the /beta rule does not set request header X-Env: canary")

    rewrite_ok = False
    for filt in filter_of(beta_rule, "URLRewrite"):
        path = (filt.get("urlRewrite") or {}).get("path") or {}
        if (path.get("type") == "ReplacePrefixMatch"
                and path.get("replacePrefixMatch") == "/"):
            rewrite_ok = True
    if not rewrite_ok:
        errors.append("the /beta rule has no URLRewrite ReplacePrefixMatch /")

# Rule 3: /old redirects 301 to /new.
redirect_rule = None
for rule in rules:
    if has_path(rule, "/old") and filter_of(rule, "RequestRedirect"):
        redirect_rule = rule
        break

if redirect_rule is None:
    errors.append("no /old RequestRedirect rule")
else:
    redirect_ok = False
    for filt in filter_of(redirect_rule, "RequestRedirect"):
        redirect = filt.get("requestRedirect") or {}
        path = redirect.get("path") or {}
        if (redirect.get("statusCode") == 301
                and path.get("type") == "ReplaceFullPath"
                and path.get("replaceFullPath") == "/new"):
            redirect_ok = True
    if not redirect_ok:
        errors.append("/old redirect is not 301 to ReplaceFullPath /new")

if errors:
    for error in errors:
        print(error)
    sys.exit(1)
print("HTTPRoute weights, matches and filters are correct")
PY

route_json=$(kubectl -n "$NS" get httproute split -o json 2>/dev/null || true)
if result=$(printf '%s' "$route_json" | python3 "$checker" 2>&1); then
  pass "$result"
else
  fail "$result"
fi
rm -f "$checker"

for svc in stable canary; do
  port=$(kubectl -n "$NS" get service "$svc" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)
  check_eq "Service $svc exposes port 80" "$port" "80"
done

summary
