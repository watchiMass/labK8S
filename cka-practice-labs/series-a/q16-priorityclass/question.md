# PriorityClass and Pod priority

Work in namespace `a16-priority`.

1. Create two PriorityClasses, neither marked as global default:
   - `high-priority`: value `100000`, preemption policy
     `PreemptLowerPriority`
   - `low-priority`: value `1000`, preemption policy `Never`
2. Create Pod `low-pod` with image `busybox:1.36`, command `sleep 3600`, and
   priority class `low-priority`.
3. Create Deployment `high-app` with 2 replicas, image `nginx:1-alpine`, and
   priority class `high-priority`.
4. Confirm the effective numeric priority in each Pod: 1000 for `low-pod`,
   100000 for the `high-app` Pods.
