# Service with manually managed Endpoints

Namespace `c2-ext` runs Deployment `mock-external` (nginx). Namespace `c2-app`
has a `client` Pod.

1. Find the Pod IP of `mock-external`.
2. In namespace `c2-app`, create a ClusterIP Service named `external-api`,
   exposing port 80, with **no selector**.
3. Create Endpoints (or an EndpointSlice) with the same name `external-api`
   pointing at the `mock-external` Pod IP on port 80.
4. From the `client` Pod, verify
   `http://external-api.c2-app.svc.cluster.local` serves the nginx page.

The Service must not select Pods in `c2-app`; traffic is routed only through
the manual Endpoints.
