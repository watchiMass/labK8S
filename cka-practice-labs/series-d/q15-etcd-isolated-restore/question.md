# Isolated etcd restore on alternate ports

Work on the control-plane node. A snapshot of the live cluster is at
`/opt/cka-practice/series-d/q15-etcd-isolated-restore/source-snapshot.db`.
The full `etcd`, `etcdctl` and `etcdutl` binary paths are written in
`tools.txt` in the same directory.

Build a **standalone** restored etcd on localhost, without touching the live
etcd:

1. Restore the snapshot into data directory `etcd-restore/` as a new
   single-member cluster:
   - member name `etcd-qa`
   - peer URL `http://127.0.0.1:12380`
   - cluster token `cka-qa`
2. Start the restored etcd server in the background:
   - client URL `http://127.0.0.1:12379`
   - peer URL `http://127.0.0.1:12380`
   - same name / initial cluster / token as above
   - write its PID to `etcd.pid` and logs to `etcd.log`
3. Query the restored key-value store for all namespace keys
   (`/registry/namespaces/`, prefix query) and write the namespace **names**,
   one per line, to `namespaces.txt`.
4. Leave the temporary etcd running so `validate.sh` can inspect it.

Do not change the live etcd, its data directory or its certificates. The
temporary instance must listen only on 127.0.0.1.
