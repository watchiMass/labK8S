# Series C — Workloads, storage and networking

16 questions. Cluster-API only — run from any machine with cluster-admin `kubectl`.

| # | Directory | Topic |
|---|---|---|
| 01 | `q01-dns-fqdn` | Service, headless Service and Pod DNS names |
| 02 | `q02-manual-endpoints` | Selector-less Service + manual Endpoints |
| 03 | `q03-storageclass-job` | StorageClass, WaitForFirstConsumer, Retain, Job |
| 04 | `q04-pv-pvc-static` | Static PV/PVC binding and mounted data |
| 05 | `q05-configmap-reload` | ConfigMap hot reload + immutable ConfigMap |
| 06 | `q06-multi-container` | emptyDir shared by three containers |
| 07 | `q07-hpa-behavior` | HPA v2 metrics + scale behaviour |
| 08 | `q08-cronjob` | CronJob schedule and job history |
| 09 | `q09-job-completions` | Job completions, parallelism, backoff |
| 10 | `q10-gateway-httproute` | HTTPRoute path and header matching |
| 11 | `q11-statefulset` | StatefulSet identity, headless DNS, PVCs |
| 12 | `q12-topology-spread` | One Pod per node with a Pending overflow |
| 13 | `q13-qos-classes` | Guaranteed / Burstable / BestEffort |
| 14 | `q14-ephemeral-debug` | `kubectl debug` ephemeral container |
| 15 | `q15-kubectl-sorting` | Two `kubectl --sort-by` scripts |
| 16 | `q16-operator-kustomize` | Fake operator logs → RBAC → Kustomize deploy |

## Prerequisites specific to this series

- A default-less dynamic provisioner is fine: C03 and C11 install
  `local-path-provisioner` automatically if no `local-path` StorageClass exists (needs
  internet).
- C10 installs the Gateway API CRDs automatically if missing. **It does not install a
  Gateway controller**; the question is validated on the HTTPRoute object.
- C08 waits for a CronJob to fire (about one minute).
- C05 waits up to three minutes for the kubelet ConfigMap sync.
