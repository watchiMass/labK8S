# etcd: version, snapshot, status, restore

Work on the control-plane node. Use the etcd certificates under
`/etc/kubernetes/pki/etcd/` and the endpoint `https://127.0.0.1:2379`.

1. Save the output of `etcd --version` (the server binary, for example from the
   etcd static Pod) to
   `/opt/cka-practice/series-b/q04-etcd-snapshot-restore/etcd-version`.
2. Take a consistent etcd snapshot with `etcdctl` and write it to
   `etcd-snapshot.db` in the same directory.
3. Run `etcdutl snapshot status` against that file and save its output to
   `etcd-snapshot-status`.
4. Restore the snapshot into a **scratch directory** named `etcd-restore/`
   using `etcdutl snapshot restore`. Never restore over the live etcd data
   directory.

Do not stop or restart etcd.
