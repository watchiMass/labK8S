# Kustomize overlay transformations

Kustomize config is at `/opt/cka-practice/series-a/q11-kustomize-overlay`, with
`base/`, `overlays/staging/` and `overlays/prod/`.

Change **only the prod overlay** so that the rendered and deployed resources
have:

1. image `nginx:1.27-alpine`
2. 3 replicas
3. an additional environment variable `LOG_LEVEL=debug` on the `web` container
   (keep `CONFIG_MODE=dev`)
4. the label `tier=frontend` on all prod resources, including the Deployment
   selector, the Pod template, and the Service selector

Apply the prod overlay to namespace `a11-prod`. The base and staging renders
must remain unchanged, and the prod Service must end up with working Endpoints.
