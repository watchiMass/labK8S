# kube-apiserver certificate expiration and renewal

Work on the control-plane node.

1. Check how long the kube-apiserver **server certificate**
   (`/etc/kubernetes/pki/apiserver.crt`) is valid using `openssl` or `cfssl`.
   Write the full expiration line (for example the `notAfter=...` output) to
   `/opt/cka-practice/series-b/q05-cert-expiration/expiration`.
2. Run `kubeadm certs check-expiration` and confirm it reports the same
   expiration date for the API server certificate.
3. Write the exact `kubeadm` command that would renew **only** the
   kube-apiserver certificate into
   `/opt/cka-practice/series-b/q05-cert-expiration/kubeadm-renew-certs.sh`.
   Do not execute the renewal.
