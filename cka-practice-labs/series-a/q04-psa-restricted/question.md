# Pod Security Admission: restricted

Namespace `a4-psa` currently has no Pod Security Admission labels, and Deployment
`legacy` is running there.

1. Configure namespace `a4-psa` so the **restricted** Pod Security Standard is
   enforced for all new Pods, using the latest available policy version.
2. Update Deployment `legacy` so its Pods are admitted and become Ready under
   the restricted profile. The container must still run `sleep 3600`, and the
   Deployment must remain named `legacy`.
3. Prove that a plain `busybox:1.36` Pod (running as root) is now rejected in
   this namespace.

Do not delete and recreate the namespace.
