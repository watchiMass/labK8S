# Projected volume: ConfigMap, Secret and downward API

Namespace `d13-projected` contains ConfigMap `app-config` (keys
`app.properties`, `feature.flag`) and Secret `app-secret` (key `password`).

Create Pod `projected-app` in `d13-projected`:

- labels: `team=platform`
- image `busybox:1.36`, command `sleep 3600`
- one projected volume named `bundle`, mounted read-only at `/etc/bundle`,
  with exactly these sources:
  1. ConfigMap `app-config`: key `app.properties` → `config/app.properties`,
     file mode `0640`
  2. Secret `app-secret`: key `password` → `secrets/password`,
     file mode `0400`
  3. downwardAPI: `metadata.name` → `meta/pod-name`, mode `0644`
  4. downwardAPI: pod label `team` → `meta/team`, mode `0644`

Verify the Pod is Running and these contents/modes inside the container:

| path | content | mode |
|---|---|---|
| `config/app.properties` | `mode=prod` + `timeout=5` | `640` |
| `secrets/password` | `secret-projected` | `400` |
| `meta/pod-name` | `projected-app` | `644` |
| `meta/team` | `platform` | `644` |

Do not create additional volumes or mount the ConfigMap/Secret separately.
