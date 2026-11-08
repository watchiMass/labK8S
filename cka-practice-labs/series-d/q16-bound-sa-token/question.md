# Token bound to a Pod must die with the Pod

Namespace `d16-token` has ServiceAccount `bound-reader` with permission to
get/list Pods in that namespace.

1. Create Pod `token-target` in `d16-token` (image `busybox:1.36`, command
   `sleep 3600`).
2. Create a ServiceAccount token for `bound-reader` with a **bound object
   reference** to kind `Pod`, name `token-target`, including that Pod's UID,
   duration 1 hour. Save the token to `token.txt` in
   `/opt/cka-practice/series-d/q16-bound-sa-token/`.
3. Using **only that token** (for example with `kubectl --token=...`), list
   Pods in `d16-token`; save the successful output to `before.txt`.
4. Delete Pod `token-target` and wait until it no longer exists.
5. Run the same authenticated request with the **same token** again and save
   the failure output to `after.txt`.

The token must be rejected after the Pod is deleted. Do not create a new
ServiceAccount token in step 5 and do not use your admin credentials for that
request.
