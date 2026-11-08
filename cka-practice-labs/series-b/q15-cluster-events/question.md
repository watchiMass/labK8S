# Cluster events and a manual container kill

Work on the control-plane node. Namespace `b15-events` runs DaemonSet
`event-target`, so one nginx Pod exists on every node, including this one.

1. Write a `kubectl` command into
   `/opt/cka-practice/series-b/q15-cluster-events/cluster_events.sh` that shows
   the latest events in the whole cluster ordered by
   `metadata.creationTimestamp`. Running the file with `bash` must work.
2. Delete the `event-target` Pod that runs on the control-plane node, wait for
   its replacement, and save the events caused by the deletion into
   `pod_kill.log`.
3. Using `crictl` on the control-plane node, manually kill the container of the
   recreated `event-target` Pod. Save the related events into
   `container_kill.log`. The container must be restarted by kubelet.

Do not scale down the DaemonSet. Do not delete the Pod a second time in step 3.
