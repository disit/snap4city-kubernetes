# snap4city-kubernetes
Follow the below steps to deploy the Kubernetes cluster for S4C on Azure multi-node VMs.

# Steps:
1. Please put changes as per your environment
-	Ensure each VM should have all the S4C ports opened individually otherwise it will go in to unwanted chaos or unknown errors. Following ports should be opened for each VM in addition to 22, 443
1026,80,3306,9200,1880,1881,9092,8088,5601,389,6443,9090,8443,8080,3001-3002,8890,9000,2181,9093,636,1030,1111
-	externalIPs to be replaced in depl-svc
sed -i 's/10.1.0.4/master-node-IP/g' *.yaml
-	All nodes hostname and /etc/hosts to be changed
10.1.0.4 kube-master
10.1.0.5 kube-node1
10.1.0.6 kube-node2
                 - Orionbrokerfilter should point to the docker orion IP container on host private IP.
                    Basically change the orionbrokerfilter-deployment.yaml template. Only the 
                    below given line value which is used to be http://orion:1026 by default:
                              - name: spring.orionbroker_endpoint
                                 value: http://10.1.0.4:1026
-	Also change the NodeSelector hostname values in yaml matching to your hostname of the node.

2.	Docker on all nodes with cfgroups fs driver settled

Refer Appendix A.

3.	Kubernetes cluster on all nodes (kubeadm, kubectl, kublet) 

Refer Appendix A.

4.	Flannel network on 10.244.x.x

Refer Appendix A.

5.	Initiate Cluser on Master Node Kube init with cidr

Refer Appendix A.

6.	Join kube worker nodes with token and certificate.

Refer Appendix A.

7.	Setup NFS server on master node /mnt/my_nfs_volumes and share nfs with all nodes
===
On NFS Server 
====
sudo apt update
sudo apt install nfs-common
sudo apt install nfs-kernel-server
sudo systemctl status nfs-server
sudo mkdir /mnt/my_nfs_volumes
sudo chown nobody:nogroup /mnt/my_nfs_volumes
sudo chmod -R 777 /mnt/my_nfs_volumes
sudo vi /etc/exports and add below line
/mnt/my_nfs_volumes *(rw,sync,no_subtree_check)
sudo exportfs -a



###Optional-  only to follow if ufw is enabled
sudo ufw status 
#if not enable skip the below steps
sudo ufw allow from 10.0.0.0/8 to any port nfs
sudo ufw allow from any to any port ssh
#This can break your ssh, flannel network and other pod communication

====
On NFS client follow this step
=====
sudo apt update
sudo apt install nfs-common
sudo mkdir -p /mnt/my_nfs_volumes
sudo mount 10.1.0.4:/mnt/my_nfs_volumes /mnt/my_nfs_volumes
#verify If they have mounted or not
df -h /mnt/my_nfs_volumes/

#on all nfs client nodes /etc/exports

sudo vim /etc/exports
10.1.0.4:/mnt/my_nfs_volumes /mnt/my_nfs_volumes nfs rw 0 0
df -h /mnt/my_nfs_volumes/


8.	Clone S4C on master server
cd ~/
git clone git clone https://github.com/disit/snap4city-docker.git

9.	Copy cloned directory to  /mnt/my_nfs_volumes


cp snap4city-docker /mnt/my_nfs_volumes

10.	Execute folder and permisions before setup

cd /mnt/my_nfs_volumes/ snap4city-docker/ DataCity-Small/
sudo ./setup.sh

11.	copy kube-s4c-working.tar in master node and untar and you will see three folder:

tar zxvf kube-s4c-working.tar 
cd kube-s4c; ls
dcompose-svc  depl-svc  pv-claim

12.	First run the kubectl create in “pvclaim” after doing the required changes of hostpath as per your cluster naming. 

cd pv-claim
kubectl create -f .


### Note: 
Over /mnt directory this does not work. So you need to choose the host path other than mounted by nfs.
13.	Now deploy Kubernetes deployment and service templates

cd depl-svc


14.	Create the required directories, first run ./setup_dir.sh

             chmod a+x setup_dir.sh
             cd dashboard/run_first
#First priority is to deploy dependent service i.e. DB, Ldap and keycloak

              kubectl create -f .
             cd ../
#Now to deploy dashboard services first.
kubectl create -f .
cd ../
#Now all other services to be deployed.
kubectl create -f .

15.	Then all deployments and services files and count them 
kubectl get depl | grep -v NAME |wc -l
20
kubectl get svc | grep -v NAME |wc -l
19
16.	Now after all services are up and running. Please copy the update-ontology.sh from depl-svc folder to /mnt/my_nfs_volumes/snap4city-docker/DataCity-Small/servicemap-conf/  and then open the virtuoso pod in interactive mode. 

cp update-ontology.sh /mnt/my_nfs_volumes/snap4city-docker/DataCity-Small/servicemap-conf/  
kubectl exec --stdin --tty virtuoso-kb-779848b595-s6lhq -- /bin/bash

17.	Please execute the following commands inside the virtuoso pod:
cd /root/servicemap/
source update-ontology.sh localhost
isql-v localhost dba dba /root/servicemap/servicemap.vt
isql-v localhost dba dba /root/servicemap/servicemap-dbpedia.vt
curl -H 'Content-Type: application/json' -X PUT 'http://elasticsearch:9200/iotdata-organization' -d @mapping_Sensors-ETL-IOT-v3.json
              

18.	Now deploy the dcompose-svc
docker-compose -f orion-compose.yaml
19.	 In total 20 pods + 1 orion docker + 1mongo docker and 19 kubesvc should be running.

# Appendix A
### KUBERNETES INSTALLATION ###########################
#### Package installation on all nodes #############
########################################################
Reference: https://www.edureka.co/blog/install-kubernetes-on-ubuntu
### Step1: Install docker on nodes
sudo apt-get install -y docker.io
####if containerd dependency si there install that too.  
sudo apt-get install -y containerd
sudo docker info | grep -i cgroup
Output: Cgroup Driver: cgroupfs ==> if this is not systemd in ubuntu. then set it.
        Cgroup Version: 1
 
##### Since the cgroup is not set to systemd so we need to provide daemon.json in docker to change it.

cat <<EOF |  tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl restart docker
#### Now Install Kubernetes Package 
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
#Add the following lines to /etc/hosts on all nodes
10.1.0.4 kube-master
10.1.0.5 kube-node1
10.1.0.6 kube-node2


### On masternode only

#### With Flannel network
sudo kubeadm init --apiserver-advertise-address=10.1.0.4 --pod-network-cidr=10.244.0.0/16
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubeadm join 10.1.0.4:6443 --token bgdxgs.ap7krw8j1h5t8uwo \
        --discovery-token-ca-cert-hash sha256:a040bd71d8ca706e26275f8bec6807af4488aa3f5e1a1ebcbebe20810cae6197
##### This should create a lot of resources in your Kubernetes cluster in master node
kubectl get nodes
kubectl get pods --all-namespaces
#All pods should be in running state
#if you want to schedule the pods on master node as well.
kubectl taint nodes --all node-role.kubernetes.io/master-
#after addition of worker node ; test workload
kubectl create deployment nginx --image=nginx
kubectl get deployment
kubectl get pod -o wide #to check on which node the pod is deployed
kubectl delete deployment nginx

#### Extra Commands
======================Token recreate and certificate ========================
sudo kubeadm token create
sudo kubeadm token list
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
   openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'
### On worker Node
sudo kubeadm join --token <token> <control-plane-host>:<control-plane-port> --discovery-token-ca-cert-hash sha256:<hash>
### OR  
### to get older certificate based on new token; 
sudo kubeadm token create <TOKEN-FROM-GENERATE-STEP> --ttl 1h --print-join-command
#----#kubectl taint nodes --all node-role.kubernetes.io/master-


### Delete or cleanup of Kubernetes cluster
#References: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
##Remove the node
##Talking to the control-plane node with the appropriate credentials, run:
kubectl delete node <node name>
kubectl drain <node name> --delete-emptydir-data --force --ignore-daemonsets

kubeadm reset 
rm -r /etc/cni/net.d
etcdctl del "" --prefix
systemctl restart kubelet docker   
### Forceful deletion######
##Reference https://containersolutions.github.io/runbooks/posts/kubernetes/pod-stuck-in-terminating-state/#solution-b
kubectl delete pod --grace-period=0 --force $(kubectl get pods | awk '{print $1}')
journalctl -xeu kubelet > error.log
#now check wht is the issue
#The reset process does not reset or clean up iptables rules or IPVS tables. If you wish to reset iptables, you must do so manually:
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
#you want to reset the IPVS tables, you must run the following command:
ipvsadm -C

#Now remove the node:

kubectl delete node <node name>
sudo docker info | grep -i cgroup
kubeadm join 10.1.0.4:6443 --token op0p62.5nx21jwr57uy0ypd --discovery-token-ca-cert-hash sha256:f318bbbb9a3b4cfa86935f287fc1ac242b4f870f611f7d8ba933169ee799cbcd

#########Delete or cleanup of Kubernetes cluster############
##References: 
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
#Remove the node
#Talking to the control-plane node with the appropriate credentials, run:
kubectl delete node <node name>
kubectl drain <node name> --delete-emptydir-data --force --ignore-daemonsets
kubeadm reset 
rm -r /etc/cni/net.d
etcdctl del "" --prefix
systemctl restart kubelet docker   or reboot system

https://levelup.gitconnected.com/how-to-use-nfs-in-kubernetes-cluster-method-1-4071724af37c

https://levelup.gitconnected.com/how-to-use-nfs-in-kubernetes-cluster-storage-class-ed1179a83817

# NFS directly
https://levelup.gitconnected.com/how-to-use-nfs-in-kubernetes-cluster-method-2-73df4efb4c00
### Delete stuck PVC in terminating state
https://veducate.co.uk/kubernetes-pvc-terminating/
kubectl get volumeattachment
kubectl patch pvc {PVC_NAME} -p '{"metadata":{"finalizers":null}}'
### disk related and to see where the drive is mounted on
sudo fdisk -l
df -ha /dev/sdb
df -ha /dev/sd*
df -h /mnt/my_nfs_volumes/

### How to troubleshoot the ws-server ?
Used for two way communication between client and server or server and server or between service and service. Basically two way communication between any two parties. Therefore it can act as a proxy server (but biderectional) also.
- used for asynchronous communication between client and server. Means generally client needs to poll the server, however using websocket connection server can send update notification to client. 
- wssocket started with http GET connection and then gets update or upgrade to ws protocol.
Solution (https://www.thenerdary.net/post/24889968081/debugging-websockets-with-curl)

https://datatracker.ietf.org/doc/html/rfc6455

