# Fix the CrashLoopBackOff

Deployment `payment-api` in namespace `b10-crash` is crash-looping.

1. Inspect the Pod status and logs to determine the cause.
2. Fix the Deployment so the Pod becomes Running and Ready.
3. Do not change the container image and do not rewrite the container command.
   The application must start through its existing entrypoint logic.
