# Server-side apply: resolve a field-manager conflict

Deployment `web` in namespace `a14-ssa` was created with server-side apply by
the field manager `platform-team`. A newer manifest is provided at
`/opt/cka-practice/series-a/q14-ssa-conflicts/update.yaml`.

Apply `update.yaml` with **server-side apply** using the field manager
`app-team`.

The apply will conflict on fields owned by `platform-team`; resolve the
conflict properly and end with:

- 3 replicas
- image `nginx:1.27-alpine`
- annotation `change-cause=scale-up`
- 3 Ready Pods

Do not use `kubectl edit`, `kubectl patch`, `kubectl scale`, or client-side
`kubectl apply`. After the apply, the object's `managedFields` must contain an
entry for `app-team` with operation `Apply`, and that manager must own the
replicas field.
