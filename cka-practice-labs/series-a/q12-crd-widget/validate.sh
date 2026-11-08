#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
info "Validating CRD schema, custom resource and admission..."

if kubectl get crd widgets.stable.example.com >/dev/null 2>&1; then
  pass "CRD widgets.stable.example.com exists"
else
  fail "CRD widgets.stable.example.com is missing"
fi

check_eq "CRD group" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath='{.spec.group}' 2>/dev/null || true)" "stable.example.com"
check_eq "CRD kind" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath='{.spec.names.kind}' 2>/dev/null || true)" "Widget"
check_eq "CRD plural" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath='{.spec.names.plural}' 2>/dev/null || true)" "widgets"
check_eq "CRD singular" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath='{.spec.names.singular}' 2>/dev/null || true)" "widget"
check_eq "CRD scope" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath='{.spec.scope}' 2>/dev/null || true)" "Namespaced"

short=$(kubectl get crd widgets.stable.example.com -o jsonpath='{.spec.names.shortNames[*]}' 2>/dev/null || true)
check_contains "CRD has short name wg" "$short" "wg"

check_eq "CRD v1 is served" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath='{.spec.versions[0].served}' 2>/dev/null || true)" "true"
check_eq "CRD v1 is the storage version" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath='{.spec.versions[0].storage}' 2>/dev/null || true)" "true"

prefix='{.spec.versions[0].schema.openAPIV3Schema.properties.spec}'
check_eq "spec.size is a string" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath="$prefix.properties.size.type" 2>/dev/null || true)" "string"
enum=$(kubectl get crd widgets.stable.example.com -o jsonpath="$prefix.properties.size.enum[*]" 2>/dev/null || true)
check_contains "size enum allows small" "$enum" "small"
check_contains "size enum allows medium" "$enum" "medium"
check_contains "size enum allows large" "$enum" "large"
check_eq "spec.replicas is an integer" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath="$prefix.properties.replicas.type" 2>/dev/null || true)" "integer"
check_eq "replicas minimum is 1" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath="$prefix.properties.replicas.minimum" 2>/dev/null || true)" "1"
check_eq "replicas maximum is 5" \
  "$(kubectl get crd widgets.stable.example.com -o jsonpath="$prefix.properties.replicas.maximum" 2>/dev/null || true)" "5"
required=$(kubectl get crd widgets.stable.example.com -o jsonpath="$prefix.required[*]" 2>/dev/null || true)
check_contains "spec requires size" "$required" "size"
check_contains "spec requires replicas" "$required" "replicas"

cols=$(kubectl get crd widgets.stable.example.com \
  -o jsonpath='{range .spec.versions[0].additionalPrinterColumns[*]}{.name}{"\n"}{end}' 2>/dev/null || true)
check_contains "printer column Size" "$cols" "Size"
check_contains "printer column Replicas" "$cols" "Replicas"
check_contains "printer column Age" "$cols" "Age"

if kubectl -n a12-crd get widget widget-sample >/dev/null 2>&1; then
  pass "Widget widget-sample exists in a12-crd"
  check_eq "widget-sample size" \
    "$(kubectl -n a12-crd get widget widget-sample -o jsonpath='{.spec.size}' 2>/dev/null || true)" "medium"
  check_eq "widget-sample replicas" \
    "$(kubectl -n a12-crd get widget widget-sample -o jsonpath='{.spec.replicas}' 2>/dev/null || true)" "2"
else
  fail "Widget widget-sample is missing in a12-crd"
fi

if kubectl -n a12-crd get wg >/dev/null 2>&1; then
  pass "short name 'wg' resolves the Widget resource"
else
  fail "short name 'wg' does not resolve"
fi

if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: stable.example.com/v1
kind: Widget
metadata:
  name: invalid-widget
  namespace: a12-crd
spec:
  size: medium
  replicas: 9
YAML
then
  fail "API server accepted replicas: 9 (schema max not enforced)"
else
  pass "API server rejects replicas: 9"
fi

summary
