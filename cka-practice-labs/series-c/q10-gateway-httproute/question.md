# Gateway API: HTTPRoute with path and header routing

Namespace `project-r500` already contains:

- Deployment/Service `desktop` (nginx, port 80)
- Deployment/Service `mobile` (nginx, port 80)
- Gateway `r500-gateway`, one HTTP listener on port 80

Create an HTTPRoute named `traffic-director` in `project-r500`, attached to
that Gateway, which implements:

1. path `/desktop` → Service `desktop` port 80
2. path `/mobile` → Service `mobile` port 80
3. path `/auto`:
   - if the request header `User-Agent` is exactly `mobile`, route to Service
     `mobile` port 80
   - otherwise route to Service `desktop` port 80

Use `PathPrefix` path matches and exact header matching. If your cluster has a
Gateway implementation running, these should work against the Gateway address:

```bash
curl http://<gateway-address>/desktop
curl http://<gateway-address>/mobile
curl http://<gateway-address>/auto -H "User-Agent: mobile"
curl http://<gateway-address>/auto
```
