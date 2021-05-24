#/bin/sh
yum update -y
yum install docker -y
yum install firewalld -y

systemctl start firewalld
systemctl enable firewalld

# hostnamectl set-hostname master-node
# cat <<EOF>> /etc/hosts
cat >/etc/hosts <<EOF
172.31.21.218 master-node
172.31.20.28 node-1 worker-node-1
EOF

sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
reboot

firewall-cmd --permanent --add-port=6783/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10255/tcp
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --reload
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

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
setenforce 0

usermod -a -G docker ec2-user
systemctl enable docker && systemctl start docker

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl restart kubelet
systemctl enable kubelet && systemctl start kubelet

# Only on worker nodes

export KUBECONFIG=/etc/kubernetes/kubelet.conf
