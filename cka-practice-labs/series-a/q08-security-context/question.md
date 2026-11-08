# Hardened Pod security context

Create a single Pod named `secure-sleeper` in namespace `a8-sec`:

- image `busybox:1.36`, command `sleep 3600`
- Pod-level security context:
  - `runAsUser: 1000`
  - `runAsGroup: 3000`
  - `fsGroup: 3000`
  - seccomp profile `RuntimeDefault`
- container security context:
  - `allowPrivilegeEscalation: false`
  - `readOnlyRootFilesystem: true`
  - drop **all** Linux capabilities
- one `emptyDir` volume mounted at `/tmp` in the container

The Pod must be Running. Prove that the container root filesystem is read-only
and that `/tmp` remains writable.
