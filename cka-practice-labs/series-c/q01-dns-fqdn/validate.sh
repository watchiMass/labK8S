#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
CTRL_NS=lima-control
WORK_NS=lima-workload
info "Validating DNS FQDN values and resolution..."

ctl_pod=$(kubectl -n "$CTRL_NS" get pods -l app=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$ctl_pod" ]]; then
  fail "controller Pod is not running"
  summary
fi

DOMAIN=$(cluster_domain "$CTRL_NS" "$ctl_pod")
pass "cluster DNS domain detected as $DOMAIN"

norm() { printf '%s' "$1" | tr -d '[:space:]' | sed 's/\.$//'; }

dns1=$(norm "$(kubectl -n "$CTRL_NS" get configmap dns-config -o jsonpath='{.data.DNS_1}' 2>/dev/null || true)")
dns2=$(norm "$(kubectl -n "$CTRL_NS" get configmap dns-config -o jsonpath='{.data.DNS_2}' 2>/dev/null || true)")
dns3=$(norm "$(kubectl -n "$CTRL_NS" get configmap dns-config -o jsonpath='{.data.DNS_3}' 2>/dev/null || true)")
dns4=$(norm "$(kubectl -n "$CTRL_NS" get configmap dns-config -o jsonpath='{.data.DNS_4}' 2>/dev/null || true)")

check_eq "DNS_1 is the kubernetes.default Service FQDN" \
  "$dns1" "kubernetes.default.svc.$DOMAIN"
check_eq "DNS_2 is the department headless Service FQDN" \
  "$dns2" "department.$WORK_NS.svc.$DOMAIN"
check_eq "DNS_3 is the section100 Pod name under the department headless Service" \
  "$dns3" "section100.department.$WORK_NS.svc.$DOMAIN"
check_eq "DNS_4 uses the Pod-IP DNS format" \
  "$dns4" "1-2-3-4.kube-system.pod.$DOMAIN"

env1=$(kubectl -n "$CTRL_NS" exec "$ctl_pod" -- printenv DNS_1 2>/dev/null || true)
env3=$(kubectl -n "$CTRL_NS" exec "$ctl_pod" -- printenv DNS_3 2>/dev/null || true)
check_eq "controller Pod received DNS_1 from the ConfigMap" "$(norm "$env1")" "$dns1"
check_eq "controller Pod received DNS_3 from the ConfigMap" "$(norm "$env3")" "$dns3"

lookup() {
  kubectl -n "$CTRL_NS" exec "$ctl_pod" -- nslookup "$1" 2>/dev/null || true
}

out1=$(lookup "$dns1")
if grep -qi 'Name:' <<<"$out1"; then
  pass "DNS_1 resolves"
else
  fail "DNS_1 does not resolve"
fi

out2=$(lookup "$dns2")
if grep -qi 'Name:' <<<"$out2"; then
  pass "DNS_2 (headless Service) resolves"
else
  fail "DNS_2 does not resolve"
fi

section_ip=$(kubectl -n "$WORK_NS" get pod section100 -o jsonpath='{.status.podIP}' 2>/dev/null || true)
out3=$(lookup "$dns3")
if grep -qi 'Name:' <<<"$out3" && [[ -n "$section_ip" ]] && grep -Fq "$section_ip" <<<"$out3"; then
  pass "DNS_3 resolves to section100 ($section_ip)"
else
  fail "DNS_3 does not resolve to section100's IP ($section_ip)"
fi

summary
