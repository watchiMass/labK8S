#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-c/q16-operator-kustomize"
ensure_workdir "$QWORK"

kubectl delete namespace c16-operator --ignore-not-found >/dev/null 2>&1 || true
kubectl delete crd students.cka.example.com courses.cka.example.com --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace c16-operator --dry-run=client -o yaml | kubectl apply -f - >/dev/null

rm -rf "$QWORK/base" "$QWORK/overlays" "$QWORK/crds"
mkdir -p "$QWORK/base" "$QWORK/overlays/prod" "$QWORK/crds"

cat > "$QWORK/crds/students.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: students.cka.example.com
spec:
  group: cka.example.com
  names:
    kind: Student
    listKind: StudentList
    plural: students
    singular: student
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                name:
                  type: string
                description:
                  type: string
YAML

cat > "$QWORK/crds/courses.yaml" <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: courses.cka.example.com
spec:
  group: cka.example.com
  names:
    kind: Course
    listKind: CourseList
    plural: courses
    singular: course
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                name:
                  type: string
                description:
                  type: string
YAML
kubectl apply -f "$QWORK/crds/" >/dev/null
kubectl wait --for=condition=Established \
  crd/students.cka.example.com crd/courses.cka.example.com --timeout=60s >/dev/null

cat > "$QWORK/base/serviceaccount.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: operator
  namespace: c16-operator
YAML

cat > "$QWORK/base/role.yaml" <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: operator-role
  namespace: c16-operator
rules:
  - apiGroups: ["cka.example.com"]
    resources: ["students", "courses"]
    verbs: ["get"]
YAML

cat > "$QWORK/base/rolebinding.yaml" <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operator-binding
  namespace: c16-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: operator-role
subjects:
  - kind: ServiceAccount
    name: operator
    namespace: c16-operator
YAML

cat > "$QWORK/base/operator-configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: operator-script
  namespace: c16-operator
data:
  operator.sh: |
    #!/bin/sh
    API="https://kubernetes.default.svc/apis/cka.example.com/v1/namespaces/c16-operator"
    CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    while true; do
      TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      for r in students courses; do
        if curl -sf --cacert "$CA" \
             -H "Authorization: Bearer $TOKEN" "$API/$r" >/dev/null; then
          echo "OK list $r"
        else
          echo "ERROR list $r: request failed (RBAC or API)"
        fi
      done
      sleep 10
    done
YAML

cat > "$QWORK/base/operator-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: operator
  namespace: c16-operator
  labels:
    app: operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: operator
  template:
    metadata:
      labels:
        app: operator
    spec:
      serviceAccountName: operator
      containers:
        - name: operator
          image: curlimages/curl:8.10.1
          command: ["/bin/sh", "/scripts/operator.sh"]
          volumeMounts:
            - name: scripts
              mountPath: /scripts
              readOnly: true
      volumes:
        - name: scripts
          configMap:
            name: operator-script
YAML

cat > "$QWORK/base/student1.yaml" <<'YAML'
apiVersion: cka.example.com/v1
kind: Student
metadata:
  name: student1
  namespace: c16-operator
spec:
  name: Alice
  description: First student
YAML

cat > "$QWORK/base/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - serviceaccount.yaml
  - role.yaml
  - rolebinding.yaml
  - operator-configmap.yaml
  - operator-deployment.yaml
  - student1.yaml
YAML

cat > "$QWORK/overlays/prod/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
YAML

kubectl apply -k "$QWORK/overlays/prod" >/dev/null
kubectl -n c16-operator rollout status deployment/operator --timeout=180s >/dev/null

sleep 5
info "Environment ready. Kustomize root: $QWORK (initial Role lacks 'list')."
