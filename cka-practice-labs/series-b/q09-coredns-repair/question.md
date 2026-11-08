# Cluster DNS is broken

Work on the control-plane node.

Pods can no longer resolve Service names to ClusterIPs. Something in the
cluster DNS add-on is misconfigured.

1. Diagnose the problem using the DNS Pods, their logs, and the CoreDNS
   configuration.
2. Fix it. Do not delete or recreate the CoreDNS Deployment, and do not change
   the kube-dns Service.
3. Prove name resolution works from a freshly created Pod: it must resolve
   `kubernetes.default`.

The fix must survive a CoreDNS Pod restart.
