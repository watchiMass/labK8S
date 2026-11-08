# Helm: chart, install, upgrade, rollback

Work in this question's directory.

1. Create a Helm chart at `webchart/` with:
   - `Chart.yaml`
   - `values.yaml` containing `replicaCount`, `image.repository`,
     `image.tag` and `service.port`
   - a Deployment named `web` and a Service named `web` rendered from those
     values, with the Service exposing port 80
2. Install release `web` into namespace `a13-helm` with `replicaCount=2` and
   image `nginx:1-alpine`. Wait for it to be Ready.
3. Upgrade the release to 3 replicas and image `nginx:1.27-alpine`.
4. Roll back to revision 1 and verify the release is deployed again with
   2 replicas running `nginx:1-alpine`.
5. Show the release history; it must contain all three revisions.

Use only your own chart, not a chart from a repository.
