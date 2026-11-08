# Inspect a node with kubectl debug

The worker node to inspect is recorded in
`./node.txt`.

1. Start a node-level debug Pod for that worker using `kubectl debug node/...`
   with a `busybox` image.
2. From inside the debug Pod, read the node's own `/etc/os-release` (the host
   filesystem is mounted under `/host`) and its kernel release.
3. Write this report on the **control-plane node** at
   `./node-report.txt`:

   ```
   PRETTY_NAME=<value from the node's /etc/os-release>
   KERNEL=<output of uname -r from the node>
   ```

4. Delete the debug Pod when finished.

The values must come from the worker's host filesystem/kernel, not from the
container image.
