# StatefulSet with stable identity and per-Pod storage

Work in namespace `c11-sts`. A StorageClass named `local-path` is available.

1. Create a headless Service named `db-headless`:
   - `clusterIP: None`
   - selector `app=db`
   - port 80/targetPort 80
2. Create a StatefulSet named `db`:
   - 3 replicas, image `nginx:1-alpine`
   - label `app=db`
   - `serviceName: db-headless`
   - container port 80
   - a `volumeClaimTemplates` entry named `data`: 20Mi, ReadWriteOnce,
     StorageClass `local-path`, mounted at `/data`
3. Wait until all three Pods are Ready and all three PVCs are Bound.
4. Scale the StatefulSet to 1 and back to 3. Confirm that the PVCs for the
   other replicas were retained and that `db-1.db-headless.c11-sts` resolves
   to the `db-1` Pod IP.
