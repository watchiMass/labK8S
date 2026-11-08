# Kubelet client and server certificate details

The worker node you must inspect is recorded in
`/opt/cka-practice/series-b/q06-kubelet-cert-info/node.txt`.

On that worker, find the `Issuer` and `Extended Key Usage` values of:

1. the **kubelet client certificate** — used for outgoing connections from
   kubelet to the kube-apiserver
2. the **kubelet server certificate** — used for incoming connections from the
   kube-apiserver to kubelet

Write the result on the **control-plane node** to
`/opt/cka-practice/series-b/q06-kubelet-cert-info/certificate-info.txt` in
exactly this shape:

```
client issuer: <value>
client eku: <value>
server issuer: <value>
server eku: <value>
```

You can run commands on the worker over SSH (or via `vagrant ssh w1` from the
host) and copy the values back. Do not change any certificate.
