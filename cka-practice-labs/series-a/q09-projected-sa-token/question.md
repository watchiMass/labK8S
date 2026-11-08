# Projected ServiceAccount token and in-cluster API access

Work in namespace `a9-api`. ServiceAccount `pod-reader` already exists.

1. Create Role `pod-reader` and RoleBinding `pod-reader-binding` granting the
   ServiceAccount `get` and `list` on Pods in `a9-api` only.
2. Create a Pod named `api-caller`:
   - image `curlimages/curl:8.10.1`, command `sleep infinity`
   - `serviceAccountName: pod-reader`
   - a projected volume named `api-token` mounted at
     `/var/run/secrets/custom`, containing a `serviceAccountToken` source with
     `path: token` and `expirationSeconds: 600`
3. From inside the Pod, use the projected token and the cluster CA to query the
   Kubernetes API with `curl`:
   - listing Pods in `a9-api` must return HTTP 200
   - listing Pods in `default` must return HTTP 403

The container image has no `kubectl`; use the token file directly.
