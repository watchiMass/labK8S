# PDB-aware node maintenance

The worker to maintain is in
`./node.txt`.
Deployment `web` (3 replicas) and PodDisruptionBudget `web-pdb`
(`minAvailable: 3`) run in namespace `d04-maint`.

With the current replica count the PDB has **zero allowed disruptions**, so a
drain using the eviction API cannot make progress.

Perform maintenance without ever reducing availability below 3:

1. Adjust the Deployment so a safe drain is possible (the PDB must not be
   edited or deleted, and eviction must go through the eviction API).
2. Drain the node: ignore DaemonSets, do not use `--force`, do not delete
   unmanaged Pods, do not disable eviction.
3. After the drain, uncordon the node.
4. Return the Deployment to exactly 3 replicas.

Constraints: do not modify the PDB, do not change node labels/taints, and do
not use `kubectl drain --disable-eviction`. End with all 3 replicas Ready and
the PDB reporting 3 healthy Pods.
