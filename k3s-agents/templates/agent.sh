#! /bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Install k3s
export INSTALL_K3S_SKIP_DOWNLOAD=true
# shellcheck disable=SC2154
export K3S_URL="https://${server_address}:6443"
# shellcheck disable=SC2154
export K3S_TOKEN="${token}"

# shellcheck disable=SC2154
/usr/local/bin/install-k3s.sh \
    --kubelet-arg=cloud-provider=external \
    --container-runtime-endpoint=/var/run/containerd/containerd.sock

mkdir -p /run/containerd/io.containerd.runtime.v1.linux/k8s.io
