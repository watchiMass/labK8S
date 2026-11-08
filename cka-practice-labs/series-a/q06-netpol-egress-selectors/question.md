# Cross-namespace NetworkPolicy

There are two namespaces:

- `a6-front`: Deployment `front` (label `app=front`)
- `a6-back`: Deployments `api` and `db` (both nginx, port 80, labels
  `app=api` / `app=db`), a `tester` Pod, and Services `api` and `db`

Create exactly two NetworkPolicies:

1. In `a6-back`, `api-ingress`: allow ingress to `app=api` Pods only from
   `app=front` Pods in namespace `a6-front`, on TCP port 80.
2. In `a6-front`, `front-egress`: allow egress from `app=front` Pods only to
   `app=api` Pods in namespace `a6-back` on TCP port 80, plus DNS to
   `kube-system` / `k8s-app=kube-dns` on TCP and UDP 53.

Do not add policies for `db` or `tester`.

Expected behaviour:

- `front` can reach `api` but not `db`
- `tester` can reach `db` but not `api`
- DNS resolution works from `front`
