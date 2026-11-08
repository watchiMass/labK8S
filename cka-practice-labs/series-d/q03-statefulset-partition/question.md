# Partitioned StatefulSet rolling update

Namespace `d03-sts` runs StatefulSet `store` with 3 replicas on
`nginx:1-alpine`, behind headless Service `store-headless`.

Perform a **partitioned** rolling update to `nginx:1.27-alpine` so that the
final state is:

- `store-0` still runs `nginx:1-alpine`
- `store-1` and `store-2` run `nginx:1.27-alpine`
- all three Pods are Ready
- the StatefulSet's rolling update partition is exactly `1`
- the headless Service and Pod identity are unchanged

Update the partition progressively (do not delete the Pods to force images).
