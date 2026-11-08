# Service without Endpoints

In namespace `b11-endpoints`:

- Deployment `backend` runs nginx
- Pod `client` exists for testing
- Service `backend` has **no Endpoints**, so `client` cannot reach
  `http://backend`

Diagnose and fix the Service/Deployment wiring.

Rules:

- do not change the Pod labels on Deployment `backend`,
- keep Service `backend` of type ClusterIP and exposing port 80,
- finish with a working `wget -qO- http://backend` from the `client` Pod.
