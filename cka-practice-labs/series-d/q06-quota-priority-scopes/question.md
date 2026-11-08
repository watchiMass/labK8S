# ResourceQuota scoped by PriorityClass

Namespace `d06-quota` exists. PriorityClasses `d06-high` (100000) and
`d06-low` (1000) already exist.

1. Create ResourceQuota `high-quota` in `d06-quota` that applies **only to Pods
   using `d06-high`**, with:
   - `pods: "2"`
   - `requests.cpu: 500m`
2. Create ResourceQuota `low-quota` that applies **only to Pods using
   `d06-low`**, with:
   - `pods: "4"`
   - `requests.cpu: 500m`
   Use `scopeSelector` with scope `PriorityClass`; do not use a default or
   unrestricted quota.
3. Create Deployment `high-app`: 2 replicas, image `busybox:1.36`, command
   `sleep 3600`, Pod template label `app=high-app`,
   `priorityClassName: d06-high`, requests CPU `200m` /
   memory `32Mi` per container.
4. Create Deployment `low-app`: 4 replicas, image `busybox:1.36`, command
   `sleep 3600`, Pod template label `app=low-app`,
   `priorityClassName: d06-low`, requests CPU `50m` /
   memory `16Mi` per container.
5. Verify both Deployments are fully Available and that creating a third
   `d06-high` Pod is rejected by quota admission.

Do not create a PriorityClass named `d06-high` twice or edit the existing
ones.
