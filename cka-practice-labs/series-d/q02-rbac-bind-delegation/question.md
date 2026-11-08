# Delegated RBAC: bind only one ClusterRole

Namespace `d02-rbac` has ServiceAccounts `delegator` and `app-reader`.
ClusterRoles `d02-pod-reader` (get/list Pods) and `d02-secret-reader`
(get Secrets) already exist.

Give `delegator` the minimum permissions needed to act as a **namespaced RBAC
delegator**:

1. It may create RoleBindings in `d02-rbac` (Role
   `d02-rolebinding-admin` + RoleBinding `d02-rolebinding-admin-binding`).
2. It may bind **only** ClusterRole `d02-pod-reader` when creating a
   RoleBinding, using a ClusterRole named `d02-delegator` and a
   ClusterRoleBinding named `d02-delegator-binding`. It must not be able to
   bind `d02-secret-reader`, `cluster-admin`, or any other role.
3. It must not be able to create ClusterRoleBindings or to grant itself extra
   permissions.

Prove the delegation works: as `delegator`, create a RoleBinding for
`d02-pod-reader` to `app-reader`, confirm `app-reader` can list Pods, and
confirm that attempts to bind `d02-secret-reader` or create a
ClusterRoleBinding are rejected. Do not grant cluster-admin.
