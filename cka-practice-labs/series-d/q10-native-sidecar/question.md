# Native sidecar container

Create one Pod named `native-sidecar` in namespace `d10-sidecar`:

- one shared `emptyDir` volume named `logs`, mounted at `/var/log` in both
  the app container and the native sidecar;
- **native sidecar** `log-shipper`:
  - image `busybox:1.36`
  - implemented as an `initContainer` with `restartPolicy: Always`
  - creates `/var/log/app.log` if needed, then runs `tail -f /var/log/app.log`
- main container `app`:
  - image `busybox:1.36`
  - every 2 seconds appends a line containing `tick` and a timestamp to
    `/var/log/app.log`

The Pod must be Running, the sidecar must be running as a sidecar (not a
one-shot init container), and `kubectl logs native-sidecar -c log-shipper` must
show the `tick` lines.
