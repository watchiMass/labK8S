# Pending Pod: taint without toleration

The worker node is recorded in
`./node.txt`.

Deployment `gpu-worker` in namespace `b12-pending` has a Pod stuck Pending.

Make the Pod run on that worker node. Constraints:

- do **not** remove the taint from the node,
- do **not** change the Deployment's nodeSelector,
- do **not** add labels or taints to any node,
- do not schedule the Pod by setting `nodeName`.

The workload must schedule through the normal scheduler path.
