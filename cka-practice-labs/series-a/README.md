# Series A — Security, policy and configuration

16 questions. Cluster-API only — you can run these from any machine with cluster-admin
`kubectl`. No control-plane file access needed.

| # | Directory | Topic |
|---|---|---|
| 01 | `q01-contexts-csr` | CSR + client certificate + kubeconfig + RBAC |
| 02 | `q02-rbac-resource-names` | RBAC limited to resource names |
| 03 | `q03-rbac-aggregation` | Aggregated ClusterRole bound with a RoleBinding |
| 04 | `q04-psa-restricted` | Pod Security Admission `restricted` |
| 05 | `q05-netpol-deny-dns` | Default-deny + DNS allow + one allowed path |
| 06 | `q06-netpol-egress-selectors` | Cross-namespace policies with combined selectors |
| 07 | `q07-quota-limitrange` | ResourceQuota + LimitRange admission |
| 08 | `q08-security-context` | Hardened Pod, read-only root filesystem |
| 09 | `q09-projected-sa-token` | Projected SA token + in-cluster API access |
| 10 | `q10-kustomize-hpa` | Kustomize overlays and prod-only HPA patch |
| 11 | `q11-kustomize-overlay` | Images, replicas, patches and labels in an overlay |
| 12 | `q12-crd-widget` | CRD schema, printer columns, rejected invalid CR |
| 13 | `q13-helm-rollback` | Chart, install, upgrade, rollback |
| 14 | `q14-ssa-conflicts` | Server-side apply field-manager conflict |
| 15 | `q15-pdb` | PodDisruptionBudget and allowed disruptions |
| 16 | `q16-priorityclass` | PriorityClass and pod priority |

## Prerequisites specific to this series

- A CNI that enforces NetworkPolicy (Cilium/Calico) for questions 05 and 06.
- `helm` for question 13.
- `openssl` for question 01.

Everything else only needs `kubectl` and the ability to pull the standard images used by
the setups (`nginx:1-alpine`, `busybox:1.36`, `curlimages/curl:8.10.1`, `httpd:2-alpine`).
