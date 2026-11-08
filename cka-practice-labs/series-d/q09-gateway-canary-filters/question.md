# Gateway API: canary weights, headers and filters

Namespace `d09-gw` contains Deployments/Services `stable` and `canary`, plus
Gateway `d09-gateway` with one HTTP listener on port 80.

Create an HTTPRoute named `split` in `d09-gw`, attached to `d09-gateway`:

1. Path prefix `/` sends **90%** of traffic to `stable` and **10%** to
   `canary` (port 80; weights must sum to 100).
2. Path prefix `/beta` **and** header `X-Channel: beta` (exact match) sends
   100% to `canary`, and applies two filters:
   - add request header `X-Env: canary`;
   - rewrite the matched path prefix `/beta` to `/`.
3. Path prefix `/old` performs a `301` redirect to the full path `/new`
   (no backend needed for this rule).

Use `PathPrefix` path matches. If a Gateway implementation is running, the
following should behave accordingly:

```bash
curl http://<gateway-address>/
curl http://<gateway-address>/beta -H "X-Channel: beta"
curl -i http://<gateway-address>/old
```
