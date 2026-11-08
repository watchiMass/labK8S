# Default deny, DNS allow, one permitted path

Namespace `a5-netpol` contains three workloads: `web` (nginx), `client` and
`blocked`. The `web` Service exposes port 80.

Implement these NetworkPolicies in `a5-netpol`:

1. `default-deny`: selects every Pod and denies all ingress and egress.
2. `allow-dns`: selects every Pod and allows egress to the cluster DNS Pods
   (`kube-system`, label `k8s-app=kube-dns`) on TCP and UDP port 53.
3. `web-from-client`: selects the `web` Pods and allows ingress only from
   `client` Pods on TCP port 80.
4. `client-to-web`: selects the `client` Pods and allows egress only to `web`
   Pods on TCP port 80.

Use the `app` label everywhere.

Result: `client` can fetch `http://web` and resolve `kubernetes.default`;
`blocked` can resolve DNS but cannot reach `web`; nothing else can reach `web`.
