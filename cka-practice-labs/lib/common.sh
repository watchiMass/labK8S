#!/usr/bin/env bash
# Shared helpers for the CKA practice labs.
# This file is meant to be sourced by setup.sh / validate.sh / cleanup.sh.
# Do not execute it directly.

CKA_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CKA_WORKROOT="/opt/cka-practice"

# shellcheck disable=SC2034
if [[ -t 1 ]]; then
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_BOLD=""
  C_RESET=""
fi

PASS_COUNT=0
FAIL_COUNT=0

info() { printf '%s[*]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '%s[PASS]%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}
fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*"
}
die() {
  printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}

summary() {
  echo
  if [[ $FAIL_COUNT -eq 0 ]]; then
    printf '%sAll checks passed (%d).%s\n' "$C_GREEN" "$PASS_COUNT" "$C_RESET"
    exit 0
  fi
  printf '%s%d check(s) failed, %d passed.%s\n' "$C_RED" "$FAIL_COUNT" "$PASS_COUNT" "$C_RESET"
  exit 1
}

check_eq() {
  local desc="$1" got="${2:-}" want="${3:-}"
  if [[ "$got" == "$want" ]]; then
    pass "$desc"
  else
    fail "$desc (got '${got}', want '${want}')"
  fi
}

check_contains() {
  local desc="$1" haystack="${2:-}" needle="${3:-}"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$desc"
  else
    fail "$desc (missing '$needle'; got '$haystack')"
  fi
}

ensure_workdir() {
  local dir="$1"
  if ! mkdir -p "$dir" 2>/dev/null; then
    die "Cannot create $dir. Run: sudo mkdir -p $CKA_WORKROOT && sudo chown -R $(id -u):$(id -g) $CKA_WORKROOT"
  fi
  [[ -w "$dir" ]] || die "Directory $dir is not writable by $(id -un). Run: sudo chown -R $(id -u):$(id -g) $CKA_WORKROOT"
}

need_kubectl() {
  command -v kubectl >/dev/null 2>&1 || die "kubectl not found in PATH."
  kubectl cluster-info >/dev/null 2>&1 || die "Cannot reach the Kubernetes API. Check your kubeconfig/context."
}

need_cmd() {
  local cmd="$1" hint="${2:-}"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command '$cmd' not found. $hint"
}

# Sets SUDO to "" when already root, or "sudo" otherwise.
need_root_or_sudo() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    SUDO=""
  else
    command -v sudo >/dev/null 2>&1 || die "This exercise needs root (or sudo) for node-level operations."
    SUDO="sudo"
  fi
}

wait_until() {
  local timeout="$1"
  shift
  local end=$((SECONDS + timeout))
  while ((SECONDS < end)); do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

wait_pod_ready() {
  local ns="$1" pod="$2" timeout="${3:-120s}"
  kubectl -n "$ns" wait --for=condition=Ready "pod/$pod" --timeout="$timeout" >/dev/null 2>&1
}

worker_nodes() {
  kubectl get nodes -l '!node-role.kubernetes.io/control-plane' \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
}

first_worker() {
  worker_nodes | head -n1
}

controlplane_node() {
  local name=""
  name=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -z "$name" ]]; then
    name=$(kubectl get nodes -l node-role.kubernetes.io/master \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  fi
  printf '%s\n' "$name"
}

# Prints the cluster DNS domain (usually cluster.local) by reading a Pod's resolv.conf.
cluster_domain() {
  local ns="$1" pod="$2" domain=""
  domain=$(kubectl -n "$ns" exec "$pod" -- cat /etc/resolv.conf 2>/dev/null \
    | awk '/^search / {for (i = 2; i <= NF; i++) {if ($i ~ /\.svc\./) {sub(/^[^.]*\.svc\./, "", $i); print $i; exit}}}')
  [[ -n "$domain" ]] || domain="cluster.local"
  printf '%s\n' "$domain"
}

# Downloads etcd/etcdctl/etcdutl into $CKA_WORKROOT/tools when they are not on PATH.
# Sets ETCD, ETCDCTL and ETCDUTL.
ensure_etcd_tools() {
  ETCD="$(command -v etcd 2>/dev/null || true)"
  ETCDCTL="$(command -v etcdctl 2>/dev/null || true)"
  ETCDUTL="$(command -v etcdutl 2>/dev/null || true)"
  if [[ -n "$ETCD" && -n "$ETCDCTL" && -n "$ETCDUTL" ]]; then
    return 0
  fi

  local version="v3.5.17"
  local arch tool_dir tmp
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "Unsupported CPU architecture '$arch' for the etcd tools download." ;;
  esac

  tool_dir="$CKA_WORKROOT/tools/etcd-$version"
  if [[ ! -x "$tool_dir/etcd" || ! -x "$tool_dir/etcdctl" || ! -x "$tool_dir/etcdutl" ]]; then
    mkdir -p "$tool_dir" || die "Cannot create $tool_dir"
    tmp="$(mktemp -d)"
    info "Downloading etcd tools ($version, linux-$arch)..."
    if ! curl -fsSL \
      "https://github.com/etcd-io/etcd/releases/download/$version/etcd-$version-linux-$arch.tar.gz" \
      -o "$tmp/etcd.tgz"; then
      rm -rf "$tmp"
      die "Could not download etcd tools. Install 'etcd-client' (etcd, etcdctl and etcdutl) with your package manager and re-run."
    fi
    tar -xzf "$tmp/etcd.tgz" -C "$tmp" || die "Could not extract the etcd tools archive."
    cp "$tmp/etcd-$version-linux-$arch/etcd" "$tool_dir/" || die "etcd missing from archive."
    cp "$tmp/etcd-$version-linux-$arch/etcdctl" "$tool_dir/" || die "etcdctl missing from archive."
    cp "$tmp/etcd-$version-linux-$arch/etcdutl" "$tool_dir/" || die "etcdutl missing from archive."
    rm -rf "$tmp"
  fi
  ETCD="$tool_dir/etcd"
  ETCDCTL="$tool_dir/etcdctl"
  ETCDUTL="$tool_dir/etcdutl"
}

# Ensures the Rancher local-path provisioner and the 'local-path' StorageClass exist.
ensure_local_path() {
  local provisioner=""
  provisioner=$(kubectl get storageclass local-path -o jsonpath='{.provisioner}' 2>/dev/null || true)
  if [[ "$provisioner" == "rancher.io/local-path" ]]; then
    return 0
  fi

  info "No usable 'local-path' StorageClass found; installing Rancher local-path-provisioner..."
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml >/dev/null \
    || die "Could not install local-path-provisioner (internet access required). Install it manually and re-run."
  kubectl -n local-path-storage rollout status deployment/local-path-provisioner --timeout=180s >/dev/null \
    || die "local-path-provisioner did not become ready."

  provisioner=$(kubectl get storageclass local-path -o jsonpath='{.provisioner}' 2>/dev/null || true)
  [[ "$provisioner" == "rancher.io/local-path" ]] \
    || die "StorageClass 'local-path' exists but does not use rancher.io/local-path."
}

# Ensures the Gateway API CRDs are installed. A Gateway controller is NOT installed.
ensure_gateway_api() {
  if kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
    return 0
  fi
  info "Gateway API CRDs not found; installing the standard channel (v1.2.1)..."
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml >/dev/null \
    || die "Could not install the Gateway API CRDs (internet access required)."
  kubectl wait --for=condition=Established \
    crd/httproutes.gateway.networking.k8s.io --timeout=60s >/dev/null \
    || die "Gateway API CRDs were applied but did not become Established."
}
