#! /bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Install k3s
export INSTALL_K3S_SKIP_DOWNLOAD=true
# shellcheck disable=SC2154
/usr/local/bin/install-k3s.sh \
    --container-runtime-endpoint=/var/run/containerd/containerd.sock \
    --write-kubeconfig-mode 400 \
    --token "${token}" \
    --tls-san "${internal_lb_ip_address}" \
    --tls-san "${external_lb_ip_address}" \
    --node-taint "CriticalAddonsOnly=true:NoExecute" \
    --disable=servicelb,traefik \
    --disable-kube-proxy \
    --flannel-backend=none \
    --cluster-cidr=192.168.0.0/16 \
    --disable-network-policy \
    --kubelet-arg=cloud-provider=external --kube-apiserver-arg=cloud-provider=external --kube-controller-arg=cloud-provider=external \
    --disable-cloud-controller \
    --datastore-endpoint "postgres://${db_user}:${db_password}@${db_host}:5432/${db_name}"

# create directory for hostpath
mkdir -p /run/containerd/io.containerd.runtime.v1.linux/k8s.io

cat <<EOF >> /root/.bashrc
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
alias k=kubectl
EOF

# use internal IP address instead of localhost
sed -i s/127.0.0.1/"${internal_lb_ip_address}"/ /etc/rancher/k3s/k3s.yaml

# setup k8s access
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Installing Calico..."
echo "
kind: ConfigMap
apiVersion: v1
metadata:
  name: kubernetes-services-endpoint
  namespace: kube-system
data:
  KUBERNETES_SERVICE_HOST: ${internal_lb_ip_address}
  KUBERNETES_SERVICE_PORT: '6443'
" | kubectl apply -f -

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

sleep 50

echo "Enabling Calico ebpf..."
calicoctl patch felixconfiguration default --patch='{"spec": {"bpfEnabled": true, "ipv6Support": false}}' || true
