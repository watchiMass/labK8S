# Kustomize: component and merged ConfigMap generator

Kustomize config is at `/opt/cka-practice/series-d/q08-kustomize-component`
with `base/` and `overlays/prod/`. The namespace is `d08-kustomize`.

Do not edit the base resources. Implement everything through the overlay and a
component:

1. Create a Kustomize **Component** at `components/sidecar` that patches
   Deployment `api`:
   - adds a sidecar container `metrics` using `busybox:1.36`, command
     `sleep 3600`;
   - adds the label `instrumented=true` to the Deployment metadata.
2. In the prod overlay:
   - include the component;
   - add a `configMapGenerator` named `api-config` with `behavior: merge`
     that sets `mode=prod` and keeps the existing `timeout=5`;
   - leave the default generated-name hash suffix enabled, and keep the
     Deployment's `envFrom` reference pointing at the generated ConfigMap;
   - set the Deployment to 3 replicas (patch).
3. Apply the prod overlay.

Final state: 3 Ready `api` Pods, the merged ConfigMap referenced with its
hashed name, the `metrics` sidecar present, and the `instrumented=true` label
on the Deployment. The base render must still show 1 replica, `mode=base`, and
no sidecar.
