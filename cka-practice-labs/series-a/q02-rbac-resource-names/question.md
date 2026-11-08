# RBAC limited to specific resource names

Work in namespace `a2-rbac`. A ServiceAccount named `auditor` already exists.

Create a Role named `cm-reader` and a RoleBinding named `auditor-binding` that
give the ServiceAccount exactly these permissions in `a2-rbac`:

- `get` on ConfigMaps named `app-config` and `app-config-2` only
- `list` and `get` on Pods
- nothing else

The RoleBinding must bind the ServiceAccount
`system:serviceaccount:a2-rbac:auditor`.

Prove the effective permissions with `kubectl auth can-i`, in particular that
`auditor` can read the two named ConfigMaps but not `other-config`, and that it
cannot list ConfigMaps at all.
