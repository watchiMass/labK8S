# DaemonSet on every node, including the control plane

In namespace `b13-ds`, create a DaemonSet named `node-agent`:

- label the Pods `app=node-agent`
- image `busybox:1.36`, command `sleep 3600`
- resource requests: CPU `10m`, memory `16Mi`
- one Pod must run on **every** node in the cluster, including the
  control-plane node, even though it is tainted

Confirm that the DaemonSet reports the same desired, current and ready counts
as the number of nodes, and that a Pod exists on the control-plane node.
