# Job with completions, parallelism and a deadline

Create a Job named `batch` in namespace `c9-job`:

- `completions: 4`
- `parallelism: 2`
- `backoffLimit: 2`
- `activeDeadlineSeconds: 180`
- image `busybox:1.36`
- command `sh -c 'echo processing; sleep 3'`
- `restartPolicy: Never`

Wait until all completions succeed, then confirm:

- 4 Pods completed successfully,
- no Pod keeps retrying,
- the Job status reports 4 succeeded.
