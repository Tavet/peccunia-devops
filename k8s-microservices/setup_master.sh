#/bin/sh
yum update -y
yum install firewalld -y

systemctl start firewalld
systemctl enable firewalld

# hostnamectl set-hostname master-node
# cat <<EOF>> /etc/hosts
cat >/etc/hosts <<EOF
172.31.30.227 master-node
172.31.20.28 node-1 worker-node-1
EOF

# this is required to allow containers to access the host filesystem, which is needed by pod networks and other services.
setenforce 0

# To completely disable it, use the below command and reboot.
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
reboot

# Configure the firewall rules on the ports.
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --permanent --add-port=10255/tcp
firewall-cmd --reload
modprobe br_netfilter
echo '1' >/proc/sys/net/bridge/bridge-nf-call-iptables

## -----------------------------------------------------------------------------------------------------------------------
# Step 2: Install DOCKER-CE on Machine

yum install docker -y 
# Add the ec2-user to the docker group so you can execute Docker commands without using sudo.
usermod -a -G docker ec2-user
systemctl enable docker && systemctl start docker

## -----------------------------------------------------------------------------------------------------------------------
# Step 3: install Kubernetes
cat <<EOF >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl restart kubelet
systemctl enable kubelet && systemctl start kubelet

# Only on the master node:
swapoff -a

# El siguiente comando desactiva el error de m??nimas CPU y memoria RAM para el cluster.
kubeadm init --pod-network-cidr=172.16.0.0/12 #--ignore-preflight-errors=all

# This will also generate a kubeadm join command with some tokens.
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Setup Pod Network
export kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"

kubectl apply -f https://docs.projectcalico.org/v3.2/getting-started/kubernetes/installation/hosted/etcd.yaml
kubectl apply -f https://docs.projectcalico.org/v3.2/getting-started/kubernetes/installation/rbac.yaml
kubectl apply -f https://docs.projectcalico.org/v3.2/getting-started/kubernetes/installation/hosted/calico.yaml

# kubeadm join 172.31.21.218:6443 --token vq049u.041sfcr3pyzkl7gt \
#        --discovery-token-ca-cert-hash sha256:1f0d8ef374c879a07e846106f1386009de8343d4aa431c7dca7337562c3cfd1f
