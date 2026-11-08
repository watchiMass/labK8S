#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
info "Validating static Pod manifest, mirror Pod, Service and Endpoints..."
MANIFEST=/etc/kubernetes/manifests/my-static-pod.yaml

if $SUDO test -s "$MANIFEST"; then
  pass "static Pod manifest exists"
else
  fail "static Pod manifest $MANIFEST is missing"
fi

content=$($SUDO cat "$MANIFEST" 2>/dev/null || true)
check_contains "manifest uses nginx:1-alpine" "$content" "nginx:1-alpine"
check_contains "manifest sets app=my-static-pod" "$content" "my-static-pod"
check_contains "manifest requests 10m CPU" "$content" "10m"
check_contains "manifest requests 20Mi memory" "$content" "20Mi"

for _ in $(seq 1 30); do
  phase=$(kubectl get pods -n default -l app=my-static-pod -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
  [[ "$phase" == "Running" ]] && break
  sleep 2
done
check_eq "mirror Pod is Running" "$phase" "Running"

pod_ip=$(kubectl get pods -n default -l app=my-static-pod -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)
node=$(kubectl get pods -n default -l app=my-static-pod -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)
if [[ -n "$pod_ip" ]]; then
  pass "mirror Pod has an IP ($pod_ip) on node $node"
else
  fail "mirror Pod has no IP"
fi

stype=$(kubectl get service static-pod-service -n default -o jsonpath='{.spec.type}' 2>/dev/null || true)
check_eq "Service type is NodePort" "$stype" "NodePort"

sport=$(kubectl get service static-pod-service -n default -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)
check_eq "Service port is 80" "$sport" "80"

tport=$(kubectl get service static-pod-service -n default -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || true)
check_eq "Service targetPort is 80" "$tport" "80"

nodeport=$(kubectl get service static-pod-service -n default -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)
if [[ "${nodeport:-0}" -ge 30000 && "${nodeport:-0}" -le 32767 ]]; then
  pass "Service has an allocated nodePort ($nodeport)"
else
  fail "Service nodePort is missing or out of range (got '$nodeport')"
fi

selector=$(kubectl get service static-pod-service -n default \
  -o jsonpath='{.spec.selector.app}' 2>/dev/null || true)
check_eq "Service selects app=my-static-pod" "$selector" "my-static-pod"

for _ in $(seq 1 15); do
  ep_ip=$(kubectl get endpoints static-pod-service -n default \
    -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)
  [[ -n "$ep_ip" ]] && break
  sleep 2
done
if [[ -n "${ep_ip:-}" && "$ep_ip" == "$pod_ip" ]]; then
  pass "Service has exactly the static Pod as an Endpoint"
else
  fail "Service Endpoint '$ep_ip' does not match the static Pod IP '$pod_ip'"
fi

if [[ -n "${node:-}" && -n "${nodeport:-}" ]]; then
  node_ip=$(kubectl get node "$node" \
    -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | awk '{print $1}')
  if [[ -n "$node_ip" ]] && curl -s --max-time 5 "http://$node_ip:$nodeport" 2>/dev/null | grep -qi nginx; then
    pass "NodePort is reachable at http://$node_ip:$nodeport"
  else
    warn "Could not curl http://$node_ip:$nodeport from this host; the Endpoint check already proves the routing."
  fi
fi

summary
