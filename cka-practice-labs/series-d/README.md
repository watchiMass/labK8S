# Series D — Very difficult mixed scenarios

16 questions, harder than Series A–C. Several combine admission control, RBAC,
scheduling, storage, DNS, batch workloads and node-level recovery in one task.

| # | Directory | Topic |
|---|---|---|
| 01 | `q01-validating-admission-policy` | ValidatingAdmissionPolicy (CEL), namespace-scoped binding |
| 02 | `q02-rbac-bind-delegation` | Delegated RBAC: `bind` on specific ClusterRoles only |
| 03 | `q03-statefulset-partition` | Partitioned rolling update, mixed Pod images |
| 04 | `q04-pdb-drain-maintenance` | PDB + drain + scale-up without availability loss |
| 05 | `q05-coredns-rewrite` | Custom DNS alias with a CoreDNS rewrite plugin |
| 06 | `q06-quota-priority-scopes` | ResourceQuota scoped by PriorityClass |
| 07 | `q07-crd-cel-validation` | CRD CEL transition rules and validation |
| 08 | `q08-kustomize-component` | Kustomize Component + merged ConfigMap generator |
| 09 | `q09-gateway-canary-filters` | HTTPRoute weights, headers, URLRewrite, redirect |
| 10 | `q10-native-sidecar` | Native sidecar (`initContainer` with `restartPolicy: Always`) |
| 11 | `q11-selector-migration` | Immutable Deployment selector migration, no downtime |
| 12 | `q12-indexed-job` | Indexed Job completions using `JOB_COMPLETION_INDEX` |
| 13 | `q13-projected-volume` | Projected ConfigMap/Secret/downwardAPI items and modes |
| 14 | `q14-node-debug` | `kubectl debug node` host inspection |
| 15 | `q15-etcd-isolated-restore` | Snapshot restore as a new single-node etcd on alternate ports |
| 16 | `q16-bound-sa-token` | Token bound to a Pod stops working after deletion |

## Prerequisites specific to this series

- Kubernetes **1.30+** for D01 (ValidatingAdmissionPolicy). D07 needs CEL CRDs
  (1.25+), D10 needs native sidecars (1.29+).
- **D04** requires at least two schedulable worker nodes and a clean lab: it
  drains a node, evicting any other workloads on it.
- **D05** edits the cluster CoreDNS ConfigMap. It saves a backup and restores
  it in `cleanup.sh`; always run cleanup.
- **D14 and D15** are node-level and need a kubeadm/containerd control plane
  with `sudo`. D15 also needs internet the first time (etcd binaries download)
  and free localhost ports 12379/12380.
- D09 installs Gateway API CRDs if missing but no Gateway controller; the route
  is validated structurally.
- D08 uses Kustomize built into `kubectl`; no standalone `kustomize` binary is
  required.

Run one question at a time and always execute `cleanup.sh` before moving on.
