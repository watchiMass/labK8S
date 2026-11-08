# PodDisruptionBudget

Namespace `a15-pdb` runs Deployment `api` with 4 replicas.

Create a PodDisruptionBudget named `api-pdb` that:

- selects the Deployment's Pods,
- guarantees that at least **2** Pods stay available during voluntary
  disruptions.

Verify the PDB status: it must match all 4 healthy Pods and report the correct
number of allowed disruptions.
