# QoS classes

Create three Pods in namespace `c13-qos`, all image `busybox:1.36` with
command `sleep 3600`:

1. `qos-guaranteed`:
   - requests: CPU `100m`, memory `64Mi`
   - limits: identical to the requests
2. `qos-burstable`:
   - requests: CPU `50m`, memory `32Mi`
   - limits: CPU `100m`, memory `64Mi`
3. `qos-besteffort`:
   - no requests and no limits at all

All three must be Running. Verify their effective `status.qosClass` values.
