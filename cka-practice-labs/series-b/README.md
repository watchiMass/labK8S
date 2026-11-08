# Series B — Troubleshooting and node operations

16 questions. **These modify the control plane.** Run them on your disposable kubeadm lab
(Vagrant `cp1`, a Killercoda CKA environment, etc.), not on anything you care about.

The scripts use `sudo` when needed and save backups under `/opt/cka-practice/...`.
`cleanup.sh` restores kubelet, scheduler and CoreDNS state. Run it even if you failed the
question.

| # | Directory | Topic |
|---|---|---|
| 01 | `q01-fix-kubelet` | Repair kubelet config and get the node Ready |
| 02 | `q02-static-pod-service` | Static Pod + NodePort Service |
| 03 | `q03-controlplane-inventory` | How each control-plane component is started |
| 04 | `q04-etcd-snapshot-restore` | etcd version, snapshot, status, restore |
| 05 | `q05-cert-expiration` | kube-apiserver cert expiry + renew command |
| 06 | `q06-kubelet-cert-info` | Kubelet client/server issuer and EKU |
| 07 | `q07-manual-scheduling` | Stop scheduler, bind a Pod manually, restore |
| 08 | `q08-fix-scheduler` | Repair a broken scheduler static manifest |
| 09 | `q09-coredns-repair` | Diagnose and fix cluster DNS |
| 10 | `q10-crashloop-fix` | Read logs, fix CrashLoopBackOff |
| 11 | `q11-endpoints-fix` | Empty Endpoints / wrong targetPort |
| 12 | `q12-taint-toleration` | Make a Pending Pod schedule without touching the node |
| 13 | `q13-daemonset-all-nodes` | DaemonSet on every node including control plane |
| 14 | `q14-drain-node` | Drain, keep availability, uncordon |
| 15 | `q15-cluster-events` | Event script + crictl container kill |
| 16 | `q16-rollout-rollback` | Diagnose a stuck rollout and roll back |

## Prerequisites specific to this series

- kubeadm control plane with the standard `/etc/kubernetes/manifests` layout.
- containerd and a working `crictl` (B15 configures `/etc/crictl.yaml` if needed).
- At least two worker nodes for B14.
- B06 needs a way to run commands on a worker (SSH from the control plane or
  `vagrant ssh w1` from the host). The report file must end up on the control plane.
- B04 downloads `etcdctl`/`etcdutl` to `/opt/cka-practice/tools` if they are missing.
