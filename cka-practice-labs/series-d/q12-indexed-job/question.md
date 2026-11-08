# Indexed Job with per-index output

Create a Job named `indexed-batch` in namespace `d12-job`:

- `completionMode: Indexed`
- `completions: 6`
- `parallelism: 3`
- `backoffLimit: 0`
- `activeDeadlineSeconds: 180`
- image `busybox:1.36`
- `restartPolicy: Never`
- each Pod must print exactly one line `index=<N>` where `<N>` is its own
  completion index (do **not** hardcode a single index), then sleep 2 seconds
- the Job must complete with all 6 indices succeeded

Verify that the Job status reports completed indices and that the logs of the
6 Pods collectively contain indices 0 through 5.
