# Operator, CRDs, RBAC and Kustomize

Kustomize config is in this question's directory.
It is already deployed to namespace `c16-operator` with:

```bash
kubectl apply -k ./overlays/prod
```

The `operator` Deployment continuously lists the custom resources
`students.cka.example.com` and `courses.cka.example.com`. Its Pod logs show
which requests currently fail because of RBAC.

1. Inspect the operator logs to identify which CRDs it needs to `list`.
2. In the **Kustomize base**, adjust Role `operator-role` so it can `list`
   (and keep `get`) those resources. Keep the access namespaced: do not create
   a ClusterRoleBinding.
3. Add a new `Student` resource named `student4` in namespace `c16-operator`
   (any name and description) to the Kustomize base.
4. Deploy the changes to prod again with Kustomize and confirm the operator
   logs no longer report permission errors for those resources.

The base configuration must contain the changes; editing only the live
cluster objects is not enough.
