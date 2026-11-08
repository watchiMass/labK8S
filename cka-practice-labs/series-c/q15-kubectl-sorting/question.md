# kubectl sorting scripts

Create two bash scripts in this question's directory.
Each script must print the standard `kubectl get pods` table (headers are
fine), and both must run successfully with `bash <script>`.

1. `find_pods.sh`: lists all Pods in all namespaces sorted by their AGE
   (`metadata.creationTimestamp`).
2. `find_pods_uid.sh`: lists all Pods in all namespaces sorted by
   `metadata.uid`.

Do not post-process with `sort`; use kubectl's own sorting.
