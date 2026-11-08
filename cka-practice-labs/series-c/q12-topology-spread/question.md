# topologySpreadConstraints: one Pod per node

In namespace `c12-spread`, create Deployment `deploy-important`:

- 3 replicas
- Deployment and Pod labels: `id=very-important`
- container `container1`: image `nginx:1-alpine`
- container `container2`: image `registry.k8s.io/pause:3.10`
- a topology spread constraint that allows **only one Pod per node**:
  - `maxSkew: 1`
  - `topologyKey: kubernetes.io/hostname`
  - `whenUnsatisfiable: DoNotSchedule`
  - label selector matching `id=very-important`

With fewer schedulable nodes than 3 replicas, the remaining Pods must stay
Pending. Every running Pod must be on a distinct node.
