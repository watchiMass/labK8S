# ConfigMap hot reload and immutability

Namespace `c5-config` runs Deployment `config-app`, which mounts ConfigMap
`app-config` at `/etc/app-config`.

1. Update `app-config` so `theme=dark` while keeping `version=1`.
2. Confirm the file `/etc/app-config/theme` inside the **already running** Pod
   changes to `dark` without restarting, deleting or replacing the Pod. Wait
   for kubelet to sync the volume.
3. Create a ConfigMap named `locked-config` (any data) that is immutable. Prove
   it: an update attempt must be rejected by the API server.

Do not use `subPath` mounts and do not restart the Deployment.
