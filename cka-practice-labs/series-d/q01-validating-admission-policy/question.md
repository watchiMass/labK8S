# ValidatingAdmissionPolicy with CEL

Namespace `d01-policy` exists. Implement policy at admission time, **without a
webhook**.

1. Create a ValidatingAdmissionPolicy named `d01-pod-rules` that applies to Pod
   `CREATE` requests **only in namespace `d01-policy`** and enforces:
   - the Pod has a `cost-center` label;
   - every container declares CPU **and** memory limits;
   - if the Pod has the label `tier=prod`, every container's CPU and memory
     requests must equal its limits.
2. Create a ValidatingAdmissionPolicyBinding named `d01-pod-rules-binding` for
   that policy with `validationActions: [Deny]`.
3. Verify the behaviour:
   - a Pod in `d01-policy` without the label or limits is rejected;
   - a `tier=prod` Pod with limits but no requests is rejected;
   - a compliant Pod in `d01-policy` is admitted;
   - an identical non-compliant Pod in `default` is still admitted, proving the
     policy is namespace-scoped.

Use server-side dry-run (`kubectl apply --dry-run=server`) to test rejections
without creating Pods.
