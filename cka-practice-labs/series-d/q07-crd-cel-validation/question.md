# CRD with CEL transition validation

Create a namespaced CRD `servers.stable.cka.io`:

- group `stable.cka.io`, kind `Server`, plural `servers`, singular `server`
- version `v1`, served and storage
- `spec` object with required fields:
  - `hostname`: string
  - `tier`: string, enum `dev` / `prod`
  - `replicas`: integer, minimum 1, maximum 10
- CEL validation rules on `spec`:
  1. `tier=prod` requires `replicas >= 2`
  2. `hostname` is immutable after creation
  3. `replicas` may never decrease

Then:

1. Create Server `web-1` in namespace `d07-crd` with tier `prod`, replicas 3,
   hostname `web.example.com`.
2. Prove with server-side dry-run:
   - a new `dev` Server with 1 replica is admitted;
   - a new `prod` Server with 1 replica is rejected;
   - changing `web-1`'s hostname is rejected;
   - decreasing `web-1` to 2 replicas is rejected;
   - increasing `web-1` to 4 replicas is allowed.

Do not use a validating webhook.
