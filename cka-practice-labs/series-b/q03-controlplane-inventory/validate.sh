#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q03-controlplane-inventory"
FILE="$QWORK/controlplane-components.txt"
info "Validating control-plane inventory..."

if [[ -s "$FILE" ]]; then
  pass "report file exists"
else
  fail "report file $FILE is missing or empty"
  summary
fi

value_of() {
  grep -iE "^[[:space:]]*$1[[:space:]]*:" "$FILE" | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//'
}

type_of() {
  value_of "$1" | awk '{print $1}'
}

expected_type() {
  local comp="$1"
  if [[ -f "/etc/kubernetes/manifests/$comp.yaml" ]]; then
    echo "static-pod"
  elif kubectl get pods -A -o name 2>/dev/null | grep -q "$comp"; then
    echo "pod"
  elif pgrep -x "$comp" >/dev/null 2>&1; then
    echo "process"
  else
    echo "not-installed"
  fi
}

if systemctl is-active --quiet kubelet 2>/dev/null || pgrep -x kubelet >/dev/null 2>&1; then
  kubelet_expected="process"
else
  kubelet_expected="not-installed"
fi
check_eq "kubelet type is correct" "$(type_of kubelet)" "$kubelet_expected"

for comp in kube-apiserver kube-scheduler kube-controller-manager etcd; do
  check_eq "$comp type is correct" "$(type_of "$comp")" "$(expected_type "$comp")"
done

dns_type=$(value_of dns | awk '{print $1}')
dns_name=$(value_of dns | awk '{print $2}')

dns_deploy=$(kubectl -n kube-system get deployment -l k8s-app=kube-dns \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$dns_deploy" ]]; then
  check_eq "DNS type is pod" "$dns_type" "pod"
  check_eq "DNS application name is $dns_deploy" "$dns_name" "$dns_deploy"
else
  warn "No kube-dns-labelled Deployment found; cannot derive the expected DNS name."
  if [[ "$dns_type" == "pod" && -n "$dns_name" ]]; then
    pass "DNS is reported as a Pod with a name"
  else
    fail "DNS type/name is not correct"
  fi
fi

summary
