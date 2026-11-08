# Static Pod and NodePort Service

Work on the control-plane node.

1. Create a static Pod manifest at
   `/etc/kubernetes/manifests/my-static-pod.yaml`:
   - name `my-static-pod`, image `nginx:1-alpine`
   - label `app=my-static-pod`
   - container port 80
   - requests: CPU `10m`, memory `20Mi`
2. Wait until kubelet has created the mirror Pod and it is Running.
3. Create a NodePort Service named `static-pod-service` in namespace `default`
   exposing port 80 of that Pod. The Service must select the static Pod and end
   up with exactly one Endpoint.
4. If possible, verify `curl http://<node-IP>:<nodePort>` returns the nginx
   page.

Note: the mirror Pod name has the node name appended; use the `app` label when
looking it up.
