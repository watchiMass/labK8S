# Node maintenance: drain and uncordon

The worker node to maintain is recorded in
`./node.txt`.
Deployment `web` in namespace `b14-drain` has 2 replicas spread across the
workers.

1. Drain that worker safely:
   - ignore DaemonSet Pods,
   - do not force-delete Pods that are not managed by a controller,
   - do not delete local data.
2. While the node is cordoned, confirm Deployment `web` still has 2 Ready
   replicas running elsewhere.
3. Uncordon the node and confirm it is schedulable and Ready again.

The workloads must stay on the other node after uncordoning; do not manually
move Pods back.
