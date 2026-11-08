# CRD, schema validation and printer columns

1. Create a namespaced CRD with:
   - group `stable.example.com`, kind `Widget`, plural `widgets`,
     singular `widget`, short name `wg`
   - one served and storage version `v1`
   - schema for `spec`:
     - `size`: string, allowed values `small`, `medium`, `large`
     - `replicas`: integer, minimum 1, maximum 5
     - both fields required
   - additional printer columns `Size` (`.spec.size`), `Replicas`
     (`.spec.replicas`, integer) and `Age` (`.metadata.creationTimestamp`)
2. Create a Widget named `widget-sample` in namespace `a12-crd` with
   `size: medium` and `replicas: 2`.
3. Verify that a Widget with `replicas: 9` is rejected by the API server.
