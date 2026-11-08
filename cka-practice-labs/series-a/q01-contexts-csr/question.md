# Contexts, CSR and kubeconfig

Work in this question's directory. The validator checks the generated files here.

You currently use cluster-admin credentials. Developer **dev-anna** (group
`dev-team`) needs her own credentials and limited access.

1. Generate an RSA 2048 private key `dev-anna.key` and a certificate signing
   request `dev-anna.csr` with subject `CN=dev-anna, O=dev-team`.
2. Create a CSR object named `dev-anna` signed by
   `kubernetes.io/kube-apiserver-client`, approve it, and save the issued
   certificate as `dev-anna.crt`.
3. Create a standalone kubeconfig `dev-anna.kubeconfig` containing:
   - a cluster entry pointing at the current cluster and its CA,
   - a user entry using `dev-anna.crt` / `dev-anna.key`,
   - a context named `dev-anna@cka` with namespace `a1-dev` as its default.
   Verify the context is set correctly in that file.
4. Create a RoleBinding named `dev-anna-view` in namespace `a1-dev` that binds
   user `dev-anna` to the built-in `view` ClusterRole.
5. Using only `dev-anna.kubeconfig`, prove that dev-anna can list Pods in
   `a1-dev` and cannot read Secrets there or list Pods in `default`.

The setup already created namespace `a1-dev` with a small Deployment.
