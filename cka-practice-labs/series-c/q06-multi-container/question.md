# Multi-container Pod with a shared volume

Create one Pod named `multi-container-playground` in namespace `c6-multi` with
three containers and one shared volume:

- The volume is ephemeral: it must not be persisted or shared outside the Pod.
  Mount it into every container.
- Container `c1`, image `nginx:1-alpine`: expose the node name in environment
  variable `MY_NODE_NAME` using the downward API field
  `spec.nodeName`.
- Container `c2`, image `busybox:1.36`: every second, append the output of
  `date` to `date.log` inside the shared volume.
  (`while true; do date >> <vol>/date.log; sleep 1; done`)
- Container `c3`, image `busybox:1.36`: continuously stream that file to
  stdout with `tail -f <vol>/date.log`.

The Pod must be Running. Confirm `c3` logs show timestamps and `c1` sees the
correct node name.
