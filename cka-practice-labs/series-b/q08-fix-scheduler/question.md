# Repair the kube-scheduler static Pod

Work on the control-plane node.

The kube-scheduler static Pod is crash-looping and new Pods stay Pending.

1. Find the cause in the static Pod manifest and fix it.
2. Confirm the kube-scheduler static Pod is Running and Ready again.
3. Create a test Pod in `default` and confirm it is scheduled automatically.

Do not delete and re-join the node, and do not touch the API server or etcd
manifests.
