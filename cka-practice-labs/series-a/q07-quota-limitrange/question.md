# ResourceQuota and LimitRange

Work in namespace `a7-quota`.

1. Create a LimitRange named `defaults` with one `Container` entry:
   - default request: CPU `100m`, memory `128Mi`
   - default limit: CPU `250m`, memory `256Mi`
   - maximum: CPU `500m`, memory `512Mi`
2. Create a ResourceQuota named `compute` with these hard limits:
   - `requests.cpu: 1`, `requests.memory: 1Gi`
   - `limits.cpu: 2`, `limits.memory: 2Gi`
   - `pods: 6`, `count/services: 4`
3. Create Deployment `quota-app` with 2 replicas, image `nginx:1-alpine`, and
   explicit resources per container:
   - requests: CPU `200m`, memory `128Mi`
   - limits: CPU `400m`, memory `256Mi`
4. Verify the Deployment is fully Available and that a Pod requesting `600m`
   CPU is rejected by admission.
