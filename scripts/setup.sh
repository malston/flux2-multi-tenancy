#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

## see https://fluxcd.io/flux/get-started/

# brew install fluxcd/tap/flux

GITHUB_USER=malston
GITHUB_REPO=flux2-multi-tenancy

# flux check --pre

mkdir -p "${__DIR}/../clusters/staging"

flux bootstrap github \
    --context=kind-kind \
    --owner="${GITHUB_USER}" \
    --repository="${GITHUB_REPO}" \
    --branch=main \
    --personal \
    --path="clusters/staging"

# kubectl get all -n flux-system
# flux get kustomizations --watch
# flux -n apps get sources git
# flux -n apps get sources helm
# watch flux -n apps get helmreleases

mkdir -p "${__DIR}/../infrastructure/observability-system"
cat > "${__DIR}/../infrastructure/observability-system/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: observability-system

resources:
  - https://github.com/wavefrontHQ/observability-for-kubernetes/releases/download/v2.9.0/wavefront-operator.yaml

patches:
  - patch: |
      - op: replace
        path: /spec/template/spec/image
        value: projects.registry.vmware.com/tanzu_observability/kubernetes-operator:2.9.0
    target:
      kind: Deployment
      name: wavefront-controller-manager
EOF

cat >> "${__DIR}/../clusters/staging/infrastructure.yaml" <<EOF
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: wavefront-operator
  namespace: flux-system
spec:
  interval: 5m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  serviceAccountName: kustomize-controller
  path: ./infrastructure/observability-system
  prune: true
EOF

# flux get kustomizations --watch
# kubectl -n default get deployments,services
# flux suspend kustomization wavefront-operator
# flux resume kustomization wavefront-operator
# flux uninstall --namespace=flux-system --silent