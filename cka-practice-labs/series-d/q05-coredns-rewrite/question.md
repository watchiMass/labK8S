# CoreDNS rewrite: internal DNS alias

Namespace `d05-dns` runs Deployment/Service `backend` (nginx) and a `client`
Pod. Cluster DNS is working normally.

Add a **CoreDNS rewrite** so that the hostname `api.internal.` (note the
trailing dot) resolves to the ClusterIP of Service `backend`.

Requirements:

- use the CoreDNS `rewrite` plugin — no `/etc/hosts`, no `hosts` plugin entry;
- keep `kubernetes.default` and all normal cluster resolution working;
- do not change the `kube-dns` Service and do not delete the CoreDNS
  Deployment;
- verify from the `client` Pod:
  - `nslookup api.internal.` returns the backend ClusterIP,
  - `nslookup kubernetes.default` still returns an address.

CoreDNS may take up to a minute to reload the Corefile.
