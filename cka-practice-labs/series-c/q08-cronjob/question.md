# CronJob with concurrency and history controls

Create a CronJob named `report` in namespace `c8-cron`:

- schedule: every minute (`*/1 * * * *`)
- image `busybox:1.36`
- command prints the current date (for example `date`)
- `concurrencyPolicy: Forbid`
- `startingDeadlineSeconds: 30`
- `successfulJobsHistoryLimit: 2`, `failedJobsHistoryLimit: 1`
- inside the Job template: `backoffLimit: 1`, `restartPolicy: Never`
- not suspended

Wait until at least one Job has completed successfully, and confirm the
CronJob status records a last successful schedule time.
