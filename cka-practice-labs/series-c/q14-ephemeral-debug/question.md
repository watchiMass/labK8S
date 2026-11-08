# Debug a running Pod with an ephemeral container

Namespace `c14-debug` contains a Pod named `target` running only a `pause`
container (no shell).

Using `kubectl debug`, add an **ephemeral container** to this existing Pod:

- name `debugger`
- image `busybox:1.36`
- command `sleep 3600`

Do not create a copy of the Pod, do not edit the Pod spec directly, and do not
delete or recreate `target`. The original Pod UID must remain unchanged.

Confirm the ephemeral container is running inside `target`.
