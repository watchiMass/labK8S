# Kustomize: replace an external autoscaler with an HPA

Kustomize config is at `/opt/cka-practice/series-a/q10-kustomize-hpa`.
It has a `base/` and the overlays `overlays/staging/` and `overlays/prod/`,
currently deployed to namespaces `a10-staging` and `a10-prod`.

1. Remove ConfigMap `horizontal-scaling-config` completely: from the Kustomize
   configuration and from both live namespaces.
2. Add a HorizontalPodAutoscaler named `api-gateway` to the **base**, targeting
   Deployment `api-gateway`:
   - minimum 2 replicas, maximum 4 replicas
   - scale on average CPU utilisation of 50%
3. In the **prod overlay only**, override the HPA maximum to 6 replicas.
   Staging must keep the base value of 4.
4. Apply the staging and prod overlays so the cluster matches the config.

Do not change the Deployment or Service manifests.
