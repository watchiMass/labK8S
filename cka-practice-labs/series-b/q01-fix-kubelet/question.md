# Fix kubelet

Work on the kubeadm control-plane node where this question was set up.

The kubelet on this node is not running, so the node is not Ready.

1. Diagnose and fix the kubelet without reinstalling or re-joining the node.
2. Confirm the node reports `Ready`.
3. Create a Pod named `success` in namespace `default`, image
   `nginx:1-alpine`, and confirm it is Running.

The fix must persist in `/var/lib/kubelet/config.yaml` (not only for the current
process). Do not modify or delete other control-plane components.
