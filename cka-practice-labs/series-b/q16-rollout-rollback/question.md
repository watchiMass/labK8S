# Stuck rollout: return to the last good revision

A recent change to Deployment `api` in namespace `b16-rollout` is not
progressing, and new Pods cannot start.

1. Inspect the rollout status, ReplicaSets and Pod events to identify the cause.
2. Return the Deployment to the previous working revision using the rollout
   history. Do not edit the Deployment spec by hand and do not use
   `kubectl set image` to put the old image back.
3. Confirm the rollout completed and all 3 Pods are Ready on the original
   image.

The Deployment revision must advance through the rollback workflow (it must be
greater than the broken revision).
