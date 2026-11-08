# Migrate an immutable Deployment selector without downtime

Namespace `d11-migrate` runs Deployment `api` (2 replicas,
`nginx:1-alpine`, selector `app=api`) behind Service `api`
(selector `app=api`, port 80).

Migration goal:

- the old Deployment `api` must no longer exist;
- a new Deployment `api-v2` must exist with:
  - 2 replicas
  - image `nginx:1.27-alpine`
  - selector `app.kubernetes.io/name=api-v2`
  - Pod template labels `app=api` **and**
    `app.kubernetes.io/name=api-v2`
- Service `api` must keep its selector `app=api` and end with 2 Endpoints
  pointing at the new Pods;
- traffic must not be dropped during the migration: bring the new Pods up and
  Ready before removing the old Deployment.

Deployment selectors are immutable. The Service selects on `app=api`, so the
new Pods must keep that label. Do not modify the Service selector and do not
change the Service name/port.
