# CKA Practice Labs

Four independent series of hands-on CKA practice exercises, in the same format as the
Killercoda CKA course: every question has its own `setup.sh`, `question.md`, `validate.sh`
and `cleanup.sh`.

The exercises are deliberately **harder and more multi-step than the real exam**. Many of
them combine two or three exam objectives in one task, and most validators test behaviour
(DNS resolution, HTTP reachability, rollout state, scheduler placement), not just YAML
fields.

- **Series A — Security, policy and configuration** (16 questions)
- **Series B — Troubleshooting and node operations** (16 questions)
- **Series C — Workloads, storage and networking** (16 questions)
- **Series D — Very difficult mixed scenarios** (16 questions)

Each series is self-contained. Questions within a series are independent of each other:
run `setup.sh`, solve, `validate.sh`, then `cleanup.sh` before moving on. Series D is the
hardest: expect admission control, RBAC delegation, partitioned rollouts, PDB-aware
maintenance, CoreDNS rewrites, CEL validation, etcd restore and bound-token invalidation.

## Requirements

| Requirement | Notes |
|---|---|
| `kubectl` with cluster-admin | Any kubeconfig; the labs do not care how you got it. |
| A disposable lab cluster | Series B edits control-plane files and restarts kubelet/scheduler/CoreDNS. Never run it on production. |
| 1 control plane + 2 workers (recommended) | B14 needs 2 schedulable workers. C12 assumes 2 workers. Most other questions work with 1 worker. |
| CNI with NetworkPolicy support | Cilium or Calico. Flannel does **not** enforce NetworkPolicy, so A05/A06 cannot pass on it. The included Vagrantfile uses Cilium. |
| Internet access from the cluster | Images are pulled from Docker Hub / registry.k8s.io. Some setups install local-path-provisioner, Gateway API CRDs or etcd client tools. |
| `helm` for A13 | Only that question needs it. |
| kubeadm + containerd + systemd for Series B | B01, B02, B04–B09, B15 rely on the standard kubeadm layout (`/etc/kubernetes/manifests`, `/var/lib/kubelet`, `/etc/kubernetes/pki`). |
| Kubernetes 1.30+ for D01 | ValidatingAdmissionPolicy is stable from 1.30. D07 needs CEL CRDs (1.25+), D10 needs native sidecars (1.29+). |
| Two workers + clean lab for D04 | D04 drains a worker; any other workload on that node is evicted. |
| kubeadm control plane + sudo for D14/D15 | D14 uses `kubectl debug node`; D15 restores etcd and starts a temporary etcd on localhost ports 12379/12380. |

## How to use a question

```bash
git clone <your-fork-url> cka-practice-labs
cd cka-practice-labs/series-a/q01-contexts-csr

bash setup.sh        # prepares namespaces/resources and the work directory
cat question.md      # solve the task in your terminal
bash validate.sh     # exit code 0 = solved, 1 = not yet
bash cleanup.sh      # removes what setup.sh created
```

`validate.sh` prints one `[PASS]`/`[FAIL]` line per check. It is safe to run repeatedly.

### Work directory

Every question writes its files to an absolute path mirroring the repo:

```
/opt/cka-practice/series-a/q01-contexts-csr/
/opt/cka-practice/series-b/q04-etcd-snapshot-restore/
```

`setup.sh` creates it. If you run as a non-root user, once per machine:

```bash
sudo mkdir -p /opt/cka-practice
sudo chown -R "$(id -u):$(id -g)" /opt/cka-practice
```

Series B questions require `sudo` for node-level changes; the scripts use it where needed
and restore original files in `cleanup.sh`. Series D also touches node state in D05/D14/D15.
**Run cleanup even if you could not solve the question** — otherwise kubelet, scheduler,
CoreDNS, taints or a temporary etcd process may be left behind.

## Using this on Killercoda

Open a Killercoda Kubernetes terminal (the CKA course environment is ideal), clone this
repository and run the questions. You are root there, so `/opt/cka-practice` just works.
The CKA course environment also has two workers and the expected certificates/tools.

> The free single-node Killercoda playground does not have the kubeadm control-plane file
> layout or a second worker. Series A, Series C and most of Series D work; Series B and
> D14/D15 need the CKA course environment or your own kubeadm cluster.

## Using this on the included Vagrant lab

From your host:

```bash
# Optional: choose a different RDP password (default: vagrant)
export CKA_DESKTOP_PASSWORD='choose-a-password'
vagrant up
```

Connect to the control-plane desktop with an RDP client (for example Remmina):

- Host: `192.168.56.10`
- Port: `3389`
- Username: `vagrant`
- Password: the value of `CKA_DESKTOP_PASSWORD`, or `vagrant` if you did not set it

The XFCE desktop includes a terminal, VSCodium, Google Chrome and Git, with the French
AZERTY keyboard layout. Disconnect and reconnect after changing the layout. Open a terminal
there to use `kubectl`; the cluster kubeconfig is already available to `vagrant`.
The RDP service is on the lab's private network and is intended for local practice only.

If RDP reaches the login screen but rejects the credentials, reset the VM account password
over SSH (this does not reprovision or alter Kubernetes):

```bash
vagrant ssh cp1
sudo passwd vagrant
```

Enter the new password twice, then reconnect over RDP as `vagrant` and select the `Xorg`
session if prompted. Do not enter the example text `choose-a-password` literally; use the
password you chose, or `vagrant` if you did not set one.

For VMs that were already created before the desktop was added, apply the new control-plane
size and install only the desktop provisioner. Do not run all provisioners on the existing
control plane, since that would rerun `kubeadm init`:

```bash
vagrant halt cp1
vagrant up cp1
vagrant provision cp1 --provision-with desktop
```

If you change `CKA_DESKTOP_PASSWORD` later, run the desktop provisioner again to update it.

Continue setup in the desktop terminal:

```bash
export KUBECONFIG="$HOME/.kube/config"
sudo mkdir -p /opt/cka-practice
sudo chown -R "$(id -u):$(id -g)" /opt/cka-practice
git clone <your-fork-url> cka-practice-labs
cd cka-practice-labs
```

Workers are reached from the host with `vagrant ssh w1` / `vagrant ssh w2`. For B06, run
the `openssl` commands on the worker and write the required report file on `cp1`.
New VMs set Bash as the default login shell for `vagrant`, so SSH sessions support command
history and standard Bash completion. To apply this change to existing VMs without rerunning
Kubernetes setup, run the shell provisioner once on each VM:

```bash
vagrant provision cp1 --provision-with interactive-shell
vagrant provision w1 --provision-with interactive-shell
vagrant provision w2 --provision-with interactive-shell
```

## Series overview

### Series A — Security, policy and configuration

| # | Question | Main skills |
|---|---|---|
| A01 | Contexts, CSR and kubeconfig | client certs, CSR approval, kubeconfig, RBAC |
| A02 | RBAC with `resourceNames` | name-scoped permissions, `auth can-i` |
| A03 | Aggregated ClusterRole | aggregation, ClusterRole vs RoleBinding |
| A04 | Pod Security Admission | `restricted` profile, namespace labels |
| A05 | NetworkPolicy default deny + DNS | ingress/egress deny, DNS allow |
| A06 | Cross-namespace NetworkPolicy | namespaceSelector + podSelector |
| A07 | ResourceQuota and LimitRange | quota keys, admission rejection |
| A08 | Hardened securityContext | non-root, read-only root, capabilities, seccomp |
| A09 | Projected SA token | TokenRequest volume, in-cluster API call |
| A10 | Kustomize HPA | overlays, removing resources, prod-only patch |
| A11 | Kustomize images/patches/labels | transformers, patches, live rollout |
| A12 | CRD and custom resource | schema, printer columns, validation |
| A13 | Helm install/upgrade/rollback | chart authoring, releases, history |
| A14 | Server-side apply conflicts | field managers, `--force-conflicts` |
| A15 | PodDisruptionBudget | selector, allowed disruptions |
| A16 | PriorityClass | values, preemption policy, pod priority |

### Series B — Troubleshooting and node operations

| # | Question | Main skills |
|---|---|---|
| B01 | Fix kubelet | kubelet config, systemd, node Ready |
| B02 | Static Pod + NodePort Service | static manifests, mirror pods, endpoints |
| B03 | Control-plane inventory | processes vs static pods vs pods |
| B04 | etcd snapshot, status and restore | etcdctl, etcdutl, cert flags |
| B05 | Certificate expiration and renewal | openssl, `kubeadm certs` |
| B06 | Kubelet client/server cert info | TLS bootstrap, issuer/EKU on a worker |
| B07 | Stop scheduler, manual scheduling | static pod removal, Binding/nodeName |
| B08 | Fix a broken scheduler | bad static-pod flag, kubelet reload |
| B09 | Repair CoreDNS | Corefile, configmap, DNS test |
| B10 | CrashLoopBackOff | logs, env fix, rollout |
| B11 | Empty Service endpoints | selector + targetPort debugging |
| B12 | Taint/toleration scheduling | fix Pending pod without touching node |
| B13 | DaemonSet on all nodes | control-plane toleration, desired count |
| B14 | Drain and uncordon | maintenance, availability, PDB-free drain |
| B15 | Cluster events + crictl | event capture, container restart |
| B16 | Rollout rollback | ImagePullBackOff, `kubectl rollout undo` |

### Series C — Workloads, storage and networking

| # | Question | Main skills |
|---|---|---|
| C01 | DNS / FQDN / headless Service | service, headless and Pod DNS forms |
| C02 | Manual Endpoints | selector-less Service, external endpoint |
| C03 | StorageClass + dynamic provisioning | WaitForFirstConsumer, Retain, Job PVC |
| C04 | Static PV/PVC binding | storageClass, volumeName, hostPath |
| C05 | ConfigMap hot reload + immutable CM | volume updates, immutability |
| C06 | Multi-container shared volume | emptyDir, downward API, sidecar |
| C07 | HPA behaviour | autoscaling/v2, scale policies |
| C08 | CronJob | schedule, concurrency, history limits |
| C09 | Job completions/parallelism | completions, backoff, deadline |
| C10 | Gateway API HTTPRoute | parentRef, path/header matches |
| C11 | StatefulSet + headless Service | stable identity, volumeClaimTemplates |
| C12 | topologySpreadConstraints | one Pod per node, Pending overflow |
| C13 | QoS classes | Guaranteed / Burstable / BestEffort |
| C14 | kubectl debug | ephemeral container on a running Pod |
| C15 | kubectl sorting scripts | `--sort-by`, all namespaces |
| C16 | Operator, CRDs, RBAC, Kustomize | logs → RBAC fix → overlay deploy |

### Series D — Very difficult mixed scenarios

| # | Question | Main skills |
|---|---|---|
| D01 | ValidatingAdmissionPolicy | CEL validation, namespace-scoped binding |
| D02 | Delegated RBAC | `bind` on selected ClusterRoles, escalation prevention |
| D03 | Partitioned StatefulSet rollout | updateStrategy partition, mixed Pod images |
| D04 | PDB-aware drain | scale-out, eviction API, availability |
| D05 | CoreDNS rewrite alias | Corefile plugin, cluster DNS, service ClusterIP |
| D06 | PriorityClass-scoped quotas | scopeSelector, admission rejection |
| D07 | CRD with CEL rules | transition rules, immutability, validation |
| D08 | Kustomize component | Component, configMapGenerator merge, hash references |
| D09 | Gateway API canary | weights, header match, URLRewrite, RequestRedirect |
| D10 | Native sidecar | restartable init container, shared emptyDir |
| D11 | Selector migration | immutable selector, zero-downtime cutover |
| D12 | Indexed Job | completionMode Indexed, `JOB_COMPLETION_INDEX` |
| D13 | Projected volume | items, per-file modes, downwardAPI |
| D14 | Node debug | `kubectl debug node`, host filesystem |
| D15 | Isolated etcd restore | snapshot restore, single-node cluster, key query |
| D16 | Bound ServiceAccount token | TokenRequest binding, invalidation after object deletion |

## Notes and troubleshooting

- **`validate.sh` fails to reach the API** — export the kubeconfig you use for the exam
  (`export KUBECONFIG=~/.kube/config`, or `/etc/kubernetes/admin.conf` on a kubeadm node).
- **Image pulls are slow** — `setup.sh` waits up to a few minutes. Re-run it if the first
  pull times out.
- **A05/A06 always fail** — your CNI probably does not implement NetworkPolicy.
- **C03/C11 stay Pending** — the local-path provisioner could not be installed (no
  internet). Install it manually, then re-run.
- **C10 has no working URL** — only the CRDs are installed by setup, not a Gateway
  controller. The validator checks the HTTPRoute configuration; run a controller (Cilium,
  Envoy Gateway, NGINX Gateway Fabric...) if you also want real traffic.
- **B-series broke something and you forgot to clean up** — re-run the question's
  `cleanup.sh`; it restores the saved original files before deleting the namespace.
- **HPA question shows `<unknown>` metrics** — metrics-server is not installed. C07 is
  validated structurally and does not require it.
