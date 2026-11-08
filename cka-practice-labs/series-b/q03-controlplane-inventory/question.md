# How are the control-plane components started?

Run this on the control-plane node.

Find out how each of these is started/installed on this node:

- kubelet
- kube-apiserver
- kube-scheduler
- kube-controller-manager
- etcd

Also find the name of the cluster DNS application and how it is started.

Write your findings to
`./controlplane-components.txt`
in exactly this structure:

```
kubelet: [TYPE]
kube-apiserver: [TYPE]
kube-scheduler: [TYPE]
kube-controller-manager: [TYPE]
etcd: [TYPE]
dns: [TYPE] [NAME]
```

Allowed `[TYPE]` values: `not-installed`, `process`, `static-pod`, `pod`.
