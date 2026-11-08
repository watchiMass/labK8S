# Aggregated ClusterRole

ServiceAccount `metrics-agent` exists in namespace `a3-agg`.

1. Create a ClusterRole `metrics-reader` that has **no rules of its own** and
   aggregates every ClusterRole labelled
   `rbac.cka/aggregate-to-metrics-reader: "true"`.
2. Create two labelled ClusterRoles:
   - `metrics-pods`: `get`, `list`, `watch` on `pods`
   - `metrics-nodes`: `get`, `list`, `watch` on `nodes`
3. Bind `metrics-reader` to the ServiceAccount with a **RoleBinding** named
   `metrics-agent-binding` in namespace `a3-agg`. Do not use a
   ClusterRoleBinding.
4. Confirm:
   - `metrics-reader` now contains the aggregated rules for Pods and Nodes,
   - the ServiceAccount can list Pods in `a3-agg`,
   - it cannot list Pods in `default`,
   - it cannot list Nodes.
