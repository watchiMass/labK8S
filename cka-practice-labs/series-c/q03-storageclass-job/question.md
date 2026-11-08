# StorageClass, dynamic provisioning and a backup Job

Work in `/opt/cka-practice/series-c/q03-storageclass-job`.

1. Create a StorageClass named `local-backup`:
   - provisioner `rancher.io/local-path`
   - `volumeBindingMode: WaitForFirstConsumer`
   - reclaim policy `Retain`, so the PV survives deletion of a bound PVC
2. Create a PersistentVolumeClaim named `backup-pvc` in namespace
   `c3-storage`:
   - 50Mi, ReadWriteOnce
   - StorageClass `local-backup`
3. Adjust the Job manifest `backup.yaml` so the Job mounts that PVC at
   `/backup`. Do not change the Job name or its command.
4. Apply the Job and verify:
   - the Job completed exactly once,
   - the PVC is Bound to a newly provisioned PV.
