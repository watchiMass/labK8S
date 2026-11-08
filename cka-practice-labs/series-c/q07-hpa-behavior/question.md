# HorizontalPodAutoscaler with scaling behaviour

Namespace `c7-hpa` runs Deployment `web` with CPU requests set.

Create an HPA named `web-hpa` targeting that Deployment:

- minimum 2, maximum 8 replicas
- target average CPU utilisation: 60%
- `behavior.scaleUp`:
  - `stabilizationWindowSeconds: 0`
  - one policy: `Pods`, value `2`, `periodSeconds: 60`
- `behavior.scaleDown`:
  - `stabilizationWindowSeconds: 300`
  - one policy: `Percent`, value `50`, `periodSeconds: 60`

Metrics-server does not need to be installed for this exercise; the HPA object
itself is what gets validated.
