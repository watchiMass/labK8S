# Static PV and PVC binding

A PersistentVolume named `manual-pv` already exists:
100Mi, ReadWriteOnce, StorageClass `manual`, reclaim policy Retain.

1. In namespace `c4-storage`, create a PVC named `data-claim` requesting
   50Mi, ReadWriteOnce, StorageClass `manual`. It must bind to `manual-pv`.
2. Create a Pod named `storage-client`:
   - image `busybox:1.36`
   - command `sh -c 'echo cka-rocks > /data/hello.txt; sleep 3600'`
   - the PVC mounted at `/data`
3. Verify the Pod is Running and `/data/hello.txt` contains exactly
   `cka-rocks`.

Do not create a new PV and do not change the existing PV's capacity.
