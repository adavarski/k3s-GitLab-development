# k3s + Gitlab (Developing for Kubernetes with k3s+GitLab)


This document outlines the steps for utilizing [k3s](https://k3s.io/) to manage a self-hosted [Gitlab](https://gitlab.com/) instance. This may be beneficial for individuals and organizations already leveraging [Kubernetes](https://kubernetes.io/) for platform development. Many applications such as Gitlab do not need sophisticated compute clusters to operate, yet k3s allows us to achieve additional continuity in the management of development operations. k3s, although slim-down, is a fully functional Kubernetes. 

[k3s gitlab diagram]

<img src="https://raw.githubusercontent.com/adavarski/k3s-gitlab-development/main/pictures/devops-toolchain-cicd.png?raw=true" width="800">

[k3s gitlab diagram]

<img src="https://raw.githubusercontent.com/adavarski/k3s-gitlab-development/main/pictures/DevOps_Toolchain.png?raw=true" width="800">

Containers have made applications like Gitlab incredibly portable, Kubernetes brings that portability to container management and [k3s] makes that portability available at the smallest of scale.

This document outlines a process for setting up a Gitlab instance in a single custom node Kubernetes (k3s) cluster on [localhost] for local development or on VM [Digital Ocean], [Linode], [Google GCP], [Amazon AWS], [Microsoft Azure], etc.

Kubernetes is a Cloud Native and Vendor Neutral solution, and if implemented well, the specific vendor should only be a high-level business concern.


# k3s+GitLab for LOCAL k8s development 

Note: For setting up Kubernetes local development environment, there are two recommended methods 

- [k3s](https://k3s.io/)
- [minikube](https://kubernetes.io/docs/setup/learning-environment/minikube/)

k3s + GitLab
k3s is 40MB binary that runs “a fully compliant production-grade
Kubernetes distribution” and requires only 512MB of RAM.
k3s is a great way to wrap applications that you may not want to run
in a full production Cluster but would like to achieve greater uniformity
in systems deployment, monitoring, and management across all
development operations. GitLab plays a central role in the development
operations of the platform. Using
k3s to host GitLab is great way to become familiar with single-Node
Clusters and with the added benefit of a management plane unified under
the Kubernetes API.

Of the two 9k3s & minikube), k3s tends to be the most viable. It is closer to a production style
deployment. To deploy GitLab via k3s, the steps you should follow are:


## Prerequisite: DNS 

Example: Setup local DNS server

```
$ sudo apt-get install bind9 bind9utils bind9-doc dnsutils
root@carbon:/etc/bind# cat named.conf.options
options {
        directory "/var/cache/bind";
        auth-nxdomain no;    # conform to RFC1035
        listen-on-v6 { any; };
        listen-on port 53 { any; };
        allow-query { any; };
        forwarders { 8.8.8.8; };
        recursion yes;
        };
root@carbon:/etc/bind# cat named.conf.local 
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
//include "/etc/bind/zones.rfc1918";
zone    "davar.com"   {
        type master;
        file    "/etc/bind/forward.davar.com";
 };

zone   "0.168.192.in-addr.arpa"        {
       type master;
       file    "/etc/bind/reverse.davar.com";
 };
root@carbon:/etc/bind# cat reverse.davar.com 
;
; BIND reverse data file for local loopback interface
;
$TTL    604800
@       IN      SOA     davar.com. root.davar.com. (
                             21         ; Serial
                         604820         ; Refresh
                          864500        ; Retry
                        2419270         ; Expire
                         604880 )       ; Negative Cache TTL

;Your Name Server Info
@       IN      NS      primary.davar.com.
primary IN      A       192.168.0.101

;Reverse Lookup for Your DNS Server
101      IN      PTR     primary.davar.com.

;PTR Record IP address to HostName
101      IN      PTR     gitlab.dev.davar.com.
101      IN      PTR     reg.gitlab.dev.davar.com.
101      IN      PTR     dev-k3s.davar.com.
root@carbon:/etc/bind# cat forward.davar.com 
;
; BIND data file for local loopback interface
;
$TTL    604800

@       IN      SOA     primary.davar.com. root.primary.davar.com. (
                              6         ; Serial
                         604820         ; Refresh
                          86600         ; Retry
                        2419600         ; Expire
                         604600 )       ; Negative Cache TTL

;Name Server Information
@       IN      NS      primary.davar.com.

;IP address of Your Domain Name Server(DNS)
primary IN       A      192.168.0.101

;Mail Server MX (Mail exchanger) Record
davar.local. IN  MX  10  mail.davar.com.

;A Record for Host names
gitlab.dev     IN       A       192.168.0.101
reg.gitlab.dev IN       A       192.168.0.101
dev-k3s        IN       A       192.168.0.101

;CNAME Record
www     IN      CNAME    www.davar.com.

$ sudo systemctl restart bind9
$ sudo systemctl enable bind9

root@carbon:/etc/bind# ping -c1 gitlab.dev.davar.com
PING gitlab.dev.davar.com (192.168.0.101) 56(84) bytes of data.
64 bytes from primary.davar.com (192.168.0.101): icmp_seq=1 ttl=64 time=0.030 ms

--- gitlab.dev.davar.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.030/0.030/0.030/0.000 ms
root@carbon:/etc/bind# nslookup gitlab.dev.davar.com
Server:		192.168.0.101
Address:	192.168.0.101#53

Name:	gitlab.dev.davar.com
Address: 192.168.0.101

$ sudo apt install resolvconf
$ cat /etc/resolvconf/resolv.conf.d/head|grep nameserver
# run "systemd-resolve --status" to see details about the actual nameservers.
nameserver 192.168.0.101
$ sudo systemctl start resolvconf.service
$ sudo systemctl enable resolvconf.service


```

## Install k3s

k3s is "Easy to install. A binary of less than 40 MB. Only 512 MB of RAM required to run." this allows us to utilized Kubernetes for managing the Gitlab application container on a single node while limited the footprint of Kubernetes itself. 

```bash
curl -sfL https://get.k3s.io | sh -
```
## Remote Access with `kubectl`

From your local workstation you should be able to issue a curl command to Kubernetes:

```bash
curl --insecure https://SERVER_IP:6443/
```

The new k3s cluster should return a **401 Unauthorized** response with the following payload:

```json
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {

  },
  "status": "Failure",
  "message": "Unauthorized",
  "reason": "Unauthorized",
  "code": 401
}
```

k3s credentials are stored on the server at `/etc/rancher/k3s/k3s.yaml`:

Review the contents of the generated `k8s.yml` file:

```bash
cat /etc/rancher/k3s/k3s.yaml
```

The `k3s.yaml` is a Kubernetes config file used by `kubectl` and contains (1) one cluster, (3) one user and a (2) context that ties them together. `kubectl` uses contexts to determine the cluster you wish to connect to and use for access credentials. The `current-context` section is the name of the context currently selected with the `kubectl config use-context` command.


![k3s.yml]

<img src="https://raw.githubusercontent.com/adavarski/k3s-gitlab-development/main/pictures/k3s-yaml.jpg?raw=true" width="550">

Ensure that kubectl is installed on your local workstation.

If you have kubectl installed on your local workstation, notice that the `k8s.yml` file on the new k3s node is a `kubectl` config file similar to the file `~/.kube/config` generated by `kubectl`.  

You can copy the entire `k8s.yml` file over to `~/.kube/config` if you have not other contexts there already, it may also be a good practice to rename the **cluster**, **user** and **context** from `default` to something more descriptive. 

If you already have clusters, user and contexts in your `~/.kube/config` you can add these new entries after renaming them. 

Another option is to create another file such as `~/.kube/gitlab-config` and set the **KUBECONFIG** environment variable to point to it. Read more about `kubectl` configuration options[contexts].

[kubectl config]

<img src="https://raw.githubusercontent.com/adavarski/k3s-gitlab-development/main/pictures/kubectl-config.jpg?raw=true" width="550">

Before you being configuring [k3s] make sure `kubectl` pointed to the correct cluster: 

```bash
kubectl config use-context gitlab-admin
```

Ensure that you can communicate with the new [k3s] cluster by requesting a list of nodes:

```bash
kubectl get nodes
```

If successful, you should get output similar to the following:

```bash
NAME     STATUS   ROLES    AGE   VERSION
carbon   Ready    master   13h   v1.19.3+k3s3

```

Example:

```
$ sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/gitlab-config
$ export KUBECONFIG=~/.kube/gitlab-config
$ kubectl cluster-info
Kubernetes master is running at https://127.0.0.1:6443
CoreDNS is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://127.0.0.1:6443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

```


### Fix k3s CoreDNS for local development

```
$ cd k8s/utils/
$ sudo cp  /var/lib/rancher/k3s/server/manifests/coredns.yaml ./coredns-fixes.yaml
$ vi coredns-fixes.yaml 
$ sudo chown $USER: coredns-fixes.yaml 
$ sudo diff coredns-fixes.yaml /var/lib/rancher/k3s/server/manifests/coredns.yaml 
75,79d74
<     davar.com:53 {
<         errors
<         cache 30
<         forward . 192.168.0.101
<     }
$ kubectl apply -f coredns-fixes.yaml
serviceaccount/coredns unchanged
Warning: rbac.authorization.k8s.io/v1beta1 ClusterRole is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 ClusterRole
clusterrole.rbac.authorization.k8s.io/system:coredns unchanged
Warning: rbac.authorization.k8s.io/v1beta1 ClusterRoleBinding is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 ClusterRoleBinding
clusterrolebinding.rbac.authorization.k8s.io/system:coredns unchanged
configmap/coredns unchanged
deployment.apps/coredns configured
service/kube-dns unchanged

# Test k8s CoreDNS (for davar.com)

$ cat dnsutils.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: dnsutils
  namespace: default
spec:
  containers:
  - name: dnsutils
    image: gcr.io/kubernetes-e2e-test-images/dnsutils:1.3
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always

$ kubectl apply -f dnsutils.yaml

$ kubectl get po dnsutils
NAME       READY   STATUS    RESTARTS   AGE
dnsutils   1/1     Running   1          22m

$ kubectl exec -i -t dnsutils -- sh
/ # host gitlab.dev.davar.com
gitlab.dev.davar.com has address 192.168.0.101


```

## Install Cert Manager / Self-Signed Certificates

Note: Let's Encrypt will be used with Cert Manager for PRODUCTION/PUBLIC when we have internet accessble public IPs and public DNS domain. davar.com is local domain, so we use Self-Signed Certificates, Let's Encrypt is using public DNS names and if you try to use Let's Encrypt for local domain and IPs you will have issue:
```
$ kubectl describe certificates gitlab-davar -n gitlab
...
  Normal   Requested  55s   cert-manager  Created new CertificateRequest resource "gitlab-davar-4v5mt"
...
$ kubectl describe certificaterequest gitlab-davar-4v5mt -n gitlab
...
$ kubectl describe challenges gitlab-davar-4v5mt -n gitlab
...
Warning  Failed     9m59s  cert-manager  Accepting challenge authorization failed: acme: authorization error for reg.gitlab.dev.davar.com: 400 urn:ietf:params:acme:error:dns: DNS problem: NXDOMAIN looking up A for reg.gitlab.dev.davar.com - check that a DNS record exists for this domain
```
Gitlab ships with Let's Encrypt capabilities, however, since we are running Gitlab through k3s (Kubernetes) Ingress (using Traefik) we need to generate Certs and provide TLS from the cluster. 
```

Install Cert Manager 

```bash
# Kubernetes 1.16+
$ kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml

# Kubernetes <1.16
$ kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager-legacy.yaml
```

Ensure that cert manager is now running:
```bash
kubectl get all -n cert-manager
```

Output:
```plain
$ kubectl get all -n cert-manager
NAME                                          READY   STATUS    RESTARTS   AGE
pod/cert-manager-cainjector-bd5f9c764-z7bh6   1/1     Running   0          13h
pod/cert-manager-webhook-5f57f59fbc-49jk7     1/1     Running   0          13h
pod/cert-manager-5597cff495-rrl52             1/1     Running   0          13h

NAME                           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/cert-manager           ClusterIP   10.43.162.66   <none>        9402/TCP   13h
service/cert-manager-webhook   ClusterIP   10.43.202.9    <none>        443/TCP    13h

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cert-manager-cainjector   1/1     1            1           13h
deployment.apps/cert-manager-webhook      1/1     1            1           13h
deployment.apps/cert-manager              1/1     1            1           13h

NAME                                                DESIRED   CURRENT   READY   AGE
replicaset.apps/cert-manager-cainjector-bd5f9c764   1         1         1       13h
replicaset.apps/cert-manager-webhook-5f57f59fbc     1         1         1       13h
replicaset.apps/cert-manager-5597cff495             1         1         1       13h


```


Add a ClusterIssuer to handle the generation of Certs cluster-wide:

```bash
kubectl apply -f ./k8s/0000-global/003-issuer.yml.SELF
kubectl apply -f ./k8s/0000-global/005-clusterissuer.yml.SELF 
```
## Install Gitlab

### QUICK INSTALLATION: kubectl create -f 00-namespace.yml ; kubectl create -f 05-certs.yml.SELF; kubectl create -f 10-services.yml ; kubectl create -f 20-configmap.yml; kubectl create -f 40-deployment.yml ; kubectl create -f 50-ingress.yml.SELF

### QUICK CLEANING: kubectl delete -f 50-ingress.yml.SELF; kubectl delete -f 40-deployment.yml; kubectl delete -f 20-configmap.yml; kubectl delete -f 10-services.yml; kubectl delete -f 05-certs.yml.SELF; kubectl delete -f 00-namespace.yml; sudo rm -rf /srv

Details bellow:

### Namespace

[./k8s/1000-gitlab/00-namespace.yml](./k8s/1000-gitlab/00-namespace.yml) creates the [Namespace] `gitlab`:

```bash
kubectl apply -f ./k8s/1000-gitlab/00-namespace.yml
```

### TLS Certificate

Generate a TLS Certificate (first edit [./k8s/1000-gitlab/05-certs.yml.SELF](./k8s/1000-gitlab/05-certs.yml.SELF) and replace **gitlab.dev.davar.com** with your domain):

```bash
kubectl apply -f ./k8s/1000-gitlab/05-certs.yml.SELF
```


### Services

[./k8s/1000-gitlab/10-service.yml](./k8s/1000-gitlab/10-service.yml) creates two **[Services]**. Service **gitlab** provides a backend service for [Ingress] to serve the Gitlab web UI. Service **gitlab-tcp** exposes port **32222** for interacting with Gitlab over ssh for operations such as git clone, push and pull.

```bash
kubectl apply -f ./k8s/1000-gitlab/10-service.yml
```

### ConfigMap
[./k8s/1000-gitlab/20-configmap.yml](./k8s/1000-gitlab/20-configmap.yml) creates a Gitlab **[ConfigMap]**.

```bash
kubectl apply -f ./k8s/1000-gitlab/20-configmap.yml
```

### Deployment
[./k8s/1000-gitlab/40-deployment.yml](./k8s/1000-gitlab/40-deployment.yml) creates a Gitlab **[Deployment]**.

```
kubectl apply -f ./k8s/1000-gitlab/40-deployment.yml
```

The Gitlab deployment launches a single Pod creating and mounting the directory `/srv/gitlab/` on the new server for the persistent storage for configuration, logs, and data (Git repos.) containers (registry) and uploads.

```yaml
        - name: config-volume
          hostPath:
            path: /srv/gitlab/config
        - name: logs-volume
          hostPath:
            path: /srv/gitlab/logs
        - name: data-volume
          hostPath:
            path: /srv/gitlab/data
        - name: reg-volume
          hostPath:
            path: /srv/gitlab/reg
        - name: uploads-volume
          hostPath:
            path: /srv/gitlab/uploads
```

### Configure (re-Configure) Gitlab

Gitlab may take a minute or more to boot. Once Gitlab is running locate the newly generated config file gitlab.rb on the server at `/srv/gitlab/config/gitlab.rb` 
If you want some changes edit this file.

Example gitlab.rb (Replace **.davar.com** with your domain.)

`/srv/gitlab/config/gitlab.rb`:
```ruby
external_url 'https://gitlab.dev.davar.com'

nginx['listen_port'] = 80
nginx['listen_https'] = false
nginx['proxy_set_headers'] = {
  'X-Forwarded-Proto' => 'https',
  'X-Forwarded-Ssl' => 'on'
}

gitlab_rails['gitlab_shell_ssh_port'] = 32222

registry_external_url 'https://reg.gitlab.dev.davar.com'

gitlab_rails['registry_enabled'] = true

registry_nginx['listen_port'] = 5050
registry_nginx['listen_https'] = false
registry_nginx['proxy_set_headers'] = {
  'X-Forwarded-Proto' => 'https',
  'X-Forwarded-Ssl' => 'on'
}

prometheus['monitor_kubernetes'] = false
```

### Ingress

The Kubernetes [Ingress] manifest [./k8s/1000-gitlab/50-ingress.yml.SELF](./k8s/1000-gitlab/50-ingress.yml.SELF) sets up Traefik to direct requests to the host IP to backend [Service] named **gitlab**.

```bash
$ kubectl apply -f ./k8s/1000-gitlab/50-ingress.yml.SELF
```

## Login

Browse to https://gitlab.dev.davar.com (replace top-level domain with your domain). **NOTE:** New Gitlab installs present a screen to set the admin (**root**) user's password. **Do this immediately** to prevent someone else from setting up Gitlab for you. 

## Note

Remember to keep the directory `/srv/gitlab` on the server backed up. 



### Check k3s 

```
$ kubectl get all --all-namespaces
NAMESPACE             NAME                                          READY   STATUS      RESTARTS   AGE
kube-system           pod/helm-install-traefik-fbmkt                0/1     Completed   0          6d4h
gitlab-managed-apps   pod/install-helm                              0/1     Error       0          4d22h
gitlab                pod/gitlab-559c46b888-w4hqt                   1/1     Running     10         4d23h
kube-system           pod/local-path-provisioner-7ff9579c6-88rrd    1/1     Running     18         6d4h
kube-system           pod/metrics-server-7b4f8b595-964g7            1/1     Running     9          6d4h
kube-system           pod/svclb-traefik-w9lq6                       2/2     Running     18         6d4h
kube-system           pod/coredns-66c464876b-lpfv4                  1/1     Running     8          5d1h
kube-system           pod/traefik-5dd496474-xbdg2                   1/1     Running     9          6d4h
cert-manager          pod/cert-manager-cainjector-bd5f9c764-z7bh6   1/1     Running     0          13h
cert-manager          pod/cert-manager-webhook-5f57f59fbc-49jk7     1/1     Running     0          13h
cert-manager          pod/cert-manager-5597cff495-rrl52             1/1     Running     0          13h
default               pod/dnsutils                                  1/1     Running     34         4d23h
default               pod/busybox                                   1/1     Running     37         5d2h

NAMESPACE      NAME                           TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
default        service/kubernetes             ClusterIP      10.43.0.1       <none>          443/TCP                      6d4h
kube-system    service/metrics-server         ClusterIP      10.43.139.93    <none>          443/TCP                      6d4h
kube-system    service/traefik-prometheus     ClusterIP      10.43.78.216    <none>          9100/TCP                     6d4h
kube-system    service/kube-dns               ClusterIP      10.43.0.10      <none>          53/UDP,53/TCP,9153/TCP       6d4h
gitlab         service/gitlab                 ClusterIP      10.43.180.10    <none>          80/TCP,5050/TCP              4d23h
gitlab         service/gitlab-ssh             NodePort       10.43.220.213   <none>          32222:32222/TCP              4d23h
kube-system    service/traefik                LoadBalancer   10.43.100.221   192.168.0.101   80:31768/TCP,443:30058/TCP   6d4h
cert-manager   service/cert-manager           ClusterIP      10.43.162.66    <none>          9402/TCP                     13h
cert-manager   service/cert-manager-webhook   ClusterIP      10.43.202.9     <none>          443/TCP                      13h

NAMESPACE     NAME                           DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-system   daemonset.apps/svclb-traefik   1         1         1       1            1           <none>          6d4h

NAMESPACE      NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
kube-system    deployment.apps/metrics-server            1/1     1            1           6d4h
kube-system    deployment.apps/coredns                   1/1     1            1           6d4h
kube-system    deployment.apps/local-path-provisioner    1/1     1            1           6d4h
gitlab         deployment.apps/gitlab                    1/1     1            1           4d23h
kube-system    deployment.apps/traefik                   1/1     1            1           6d4h
cert-manager   deployment.apps/cert-manager-cainjector   1/1     1            1           13h
cert-manager   deployment.apps/cert-manager-webhook      1/1     1            1           13h
cert-manager   deployment.apps/cert-manager              1/1     1            1           13h

NAMESPACE      NAME                                                DESIRED   CURRENT   READY   AGE
kube-system    replicaset.apps/metrics-server-7b4f8b595            1         1         1       6d4h
kube-system    replicaset.apps/coredns-66c464876b                  1         1         1       6d4h
kube-system    replicaset.apps/local-path-provisioner-7ff9579c6    1         1         1       6d4h
gitlab         replicaset.apps/gitlab-559c46b888                   1         1         1       4d23h
kube-system    replicaset.apps/traefik-5dd496474                   1         1         1       6d4h
cert-manager   replicaset.apps/cert-manager-cainjector-bd5f9c764   1         1         1       13h
cert-manager   replicaset.apps/cert-manager-webhook-5f57f59fbc     1         1         1       13h
cert-manager   replicaset.apps/cert-manager-5597cff495             1         1         1       13h

NAMESPACE     NAME                             COMPLETIONS   DURATION   AGE
kube-system   job.batch/helm-install-traefik   1/1           44s        6d4h


$ kubectl get ingress -n gitlab
Warning: extensions/v1beta1 Ingress is deprecated in v1.14+, unavailable in v1.22+; use networking.k8s.io/v1 Ingress
NAME        CLASS    HOSTS   ADDRESS         PORTS   AGE
gitlab-ui   <none>   *       192.168.0.101   80      6m24s

$ kubectl get ingress -n gitlab
NAME     CLASS    HOSTS                                           ADDRESS         PORTS     AGE
gitlab   <none>   gitlab.dev.davar.com,reg.gitlab.dev.davar.com   192.168.0.101   80, 443   51m


$  kubectl describe certificate -n gitlab gitlab-davar
Name:         gitlab-davar
Namespace:    gitlab
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Certificate
Metadata:
  Creation Timestamp:  2020-11-26T09:51:35Z
  Generation:          1
  Managed Fields:
    API Version:  cert-manager.io/v1alpha2
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        .:
        f:commonName:
        f:dnsNames:
        f:issuerRef:
          .:
          f:kind:
          f:name:
        f:secretName:
    Manager:      kubectl-create
    Operation:    Update
    Time:         2020-11-26T09:51:35Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:spec:
        f:privateKey:
      f:status:
        f:conditions:
        f:notAfter:
        f:notBefore:
        f:renewalTime:
        f:revision:
    Manager:         controller
    Operation:       Update
    Time:            2020-11-26T09:51:36Z
  Resource Version:  165653
  Self Link:         /apis/cert-manager.io/v1/namespaces/gitlab/certificates/gitlab-davar
  UID:               4ae40b59-0aac-49b5-9e24-cd9aa2988752
Spec:
  Common Name:  gitlab.dev.davar.com
  Dns Names:
    gitlab.dev.davar.com
    reg.gitlab.dev.davar.com
  Issuer Ref:
    Kind:       ClusterIssuer
    Name:       selfsigned-issuer
  Secret Name:  gitlab-davar-tls
Status:
  Conditions:
    Last Transition Time:  2020-11-26T09:51:36Z
    Message:               Certificate is up to date and has not expired
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2021-02-24T09:51:36Z
  Not Before:              2020-11-26T09:51:36Z
  Renewal Time:            2021-01-25T09:51:36Z
  Revision:                1
Events:
  Type    Reason     Age   From          Message
  ----    ------     ----  ----          -------
  Normal  Issuing    52m   cert-manager  Issuing certificate as Secret does not exist
  Normal  Generated  52m   cert-manager  Stored new private key in temporary Secret resource "gitlab-davar-m48st"
  Normal  Requested  52m   cert-manager  Created new CertificateRequest resource "gitlab-davar-wzpmk"
  Normal  Issuing    52m   cert-manager  The certificate has been successfully issued

```


# k3s+GitLab for k8s Development on some Public Cloud 

## Obtain a Server or VM Instance on some Public Cloud Provider 

Utilize one instance of a **2 CPU / 4096MB Memory** **Ubuntu 18.04 x64** server for example on [Digital Ocean], [Linode], [Google GCP], [Amazon AWS], etc.  with Private(Public:optional) Networking enabled and a "Server Hostname & Label" of **gitlab.dev.davar.com**. 

## Configure DNS

Add DNS `A` records for your domain, such as: **gitlab.dev.davar.com** and ***.gitlab.dev.davar.com** pointed to the public IP address of the VM instance above. See your Domain Name / DNS provider for instructions on adding `A` records.

## Prepare Server

Login to the new server (IP) as the root user:

```bash
ssh root@NEW_SERVER_IP
```

Upgrade any outdated packages:

```bash
apt update && apt upgrade -y
```

## Install k3s

k3s is "Easy to install. A binary of less than 40 MB. Only 512 MB of RAM required to run." this allows us to utilized Kubernetes for managing the Gitlab application container on a single node while limited the footprint of Kubernetes itself. 

```bash
curl -sfL https://get.k3s.io | sh -
```

k3s is now installed and the Kubernetes API is listening on the public IP of the server through port **6443**. 


## Remote Access with `kubectl`

From your local workstation you should be able to issue a [curl] command to Kubernetes:

```bash
curl --insecure https://SERVER_IP:6443/
```

The new [k3s] cluster should return a **401 Unauthorized** response with the following payload:

```json
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {

  },
  "status": "Failure",
  "message": "Unauthorized",
  "reason": "Unauthorized",
  "code": 401
}
```

[k3s] credentials are stored on the server at `/etc/rancher/k3s/k3s.yaml`:

Review the contents of the generated `k8s.yml` file:

```bash
cat /etc/rancher/k3s/k3s.yaml
```

The `k3s.yaml` is a Kubernetes config file used by `kubectl` and contains (1) one cluster, (3) one user and a (2) context that ties them together. `kubectl` uses [contexts] to determine the cluster you wish to connect to and use for access credentials. The `current-context` section is the name of the context currently selected with the `kubectl config use-context` command.


[k3s.yml]

<img src="https://raw.githubusercontent.com/adavarski/k3s-gitlab-development/main/pictures/k3s-yaml.jpg?raw=true" width="550">

Ensure that kubectl is installed on your local workstation.

If you have kubectl installed on your local workstation, notice that the `k8s.yml` file on the new k3s node is a `kubectl` config file similar to the file `~/.kube/config` generated by `kubectl`.  

You can copy the entire `k8s.yml` file over to `~/.kube/config` if you have not other contexts there already, it may also be a good practice to rename the **cluster**, **user** and **context** from `default` to something more descriptive. 

If you already have clusters, user and contexts in your `~/.kube/config` you can add these new entries after renaming them. 

Another option is to create another file such as `~/.kube/gitlab-config` and set the **KUBECONFIG** environment variable to point to it. Read more about `kubectl` configuration options[contexts].

[kubectl config]

<img src="https://raw.githubusercontent.com/adavarski/k3s-gitlab-development/main/pictures/kubectl-config.jpg?raw=true" width="550">

Before you being configuring [k3s] make sure `kubectl` pointed to the correct cluster: 

```bash
kubectl config use-context gitlab-admin
```

Ensure that you can communicate with the new [k3s] cluster by requesting a list of nodes:

```bash
kubectl get nodes
```

If successful, you should get output similar to the following:

```bash
NAME                   STATUS   ROLES    AGE    VERSION
gitlab.dev.davar.com   Ready    master   13h    v1.19.3+k3s3
```

Example:
```
$ scp root@SERVER_IP_OR_CLOUD_VM:/etc/rancher/k3s/k3s.yaml ~/.kube/gitlab-config
$ export KUBECONFIG=~/.kube/gitlab-config
$ kubectl cluster-info
....
To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

```

## Install Cert Manager / Let's Encrypt

Gitlab ships with [Let's Encrypt] capabilities, however, since we are running Gitlab through k3s (Kubernetes) Ingress (using Traefik) we need to generate Certs and provide TLS from the cluster. 

Install Cert Manager 

```bash
# Kubernetes 1.16+
$ kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.yaml

# Kubernetes <1.16
$ kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager-legacy.yaml
```

Ensure that cert manager is now running:
```bash
kubectl get all -n cert-manager
```

Output:
```plain
$ kubectl get all -n cert-manager
NAME                                           READY   STATUS    RESTARTS   AGE
pod/cert-manager-6d87886d5c-2q4rl              1/1     Running   2          31h
pod/cert-manager-webhook-6846f844ff-b4xjf      1/1     Running   1          31h
pod/cert-manager-cainjector-55db655cd8-xmrj4   1/1     Running   0          13s

NAME                           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/cert-manager-webhook   ClusterIP   10.43.118.224   <none>        443/TCP    31h
service/cert-manager           ClusterIP   10.43.133.245   <none>        9402/TCP   31h

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cert-manager              1/1     1            1           31h
deployment.apps/cert-manager-webhook      1/1     1            1           31h
deployment.apps/cert-manager-cainjector   1/1     1            1           31h

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/cert-manager-6d87886d5c              1         1         1       31h
replicaset.apps/cert-manager-webhook-6846f844ff      1         1         1       31h
replicaset.apps/cert-manager-cainjector-55db655cd8   1         1         1       31h

```


Add a ClusterIssuer to handle the generation of Certs cluster-wide:

***NOTE:** First edit [./k8s/0000-global/005-clusterissuer.yml](./k8s/0000-global/005-clusterissuer.yml) and replace **YOUR_EMAIL_ADDRESS** with your email address.

```bash
kubectl apply -f ./k8s/0000-global/005-clusterissuer.yml 
```

## Install Gitlab

### Namespace

[./k8s/1000-gitlab/00-namespace.yml](./k8s/1000-gitlab/00-namespace.yml) creates the [Namespace] `gitlab`:

```bash
kubectl apply -f ./k8s/1000-gitlab/00-namespace.yml
```

### TLS Certificate

Generate a TLS Certificate (first edit [./k8s/1000-gitlab/05-certs.yml](./k8s/1000-gitlab/05-certs.yml) and replace **gitlab.dev** with your domain):

```bash
kubectl apply -f ./k8s/1000-gitlab/05-certs.yml
```

### Services

[./k8s/1000-gitlab/10-service.yml](./k8s/1000-gitlab/10-service.yml) creates two **[Services]**. Service **gitlab** provides a backend service for Ingress to serve the Gitlab web UI. Service **gitlab-tcp** exposes port **32222** for interacting with Gitlab over ssh for operations such as git clone, push and pull.

```bash
kubectl apply -f ./k8s/1000-gitlab/10-service.yml
```

### ConfigMap
[./k8s/1000-gitlab/20-configmap.yml](./k8s/1000-gitlab/20-configmap.yml) creates a Gitlab **[ConfigMap]**.

```bash
kubectl apply -f ./k8s/1000-gitlab/20-configmap.yml
```

### Deployment
[./k8s/1000-gitlab/40-deployment.yml](./k8s/1000-gitlab/40-deployment.yml) creates a Gitlab **[Deployment]**.

```
kubectl apply -f ./k8s/1000-gitlab/40-deployment.yml
```

The Gitlab deployment launches a single Pod creating and mounting the directory `/srv/gitlab/` on the new server for the persistent storage for configuration, logs, and data (Git repos.) containers (registry) and uploads.

```yaml
        - name: config-volume
          hostPath:
            path: /srv/gitlab/config
        - name: logs-volume
          hostPath:
            path: /srv/gitlab/logs
        - name: data-volume
          hostPath:
            path: /srv/gitlab/data
        - name: reg-volume
          hostPath:
            path: /srv/gitlab/reg
        - name: uploads-volume
          hostPath:
            path: /srv/gitlab/uploads
```

### Configure(re-Configure) Gitlab

Gitlab may take a minute or more to boot. Once Gitlab is running locate the newly generated config file gitlab.rb on the server at `/srv/gitlab/config/gitlab.rb`. 

Edit`gitlab.rb` file for reconfiguration. Replace **.gitlab.dev.davar.com** with your domain.

Example:

`/srv/gitlab/config/gitlab.rb`:
```ruby
external_url 'https://gitlab.dev.davar.com'

nginx['listen_port'] = 80
nginx['listen_https'] = false
nginx['proxy_set_headers'] = {
  'X-Forwarded-Proto' => 'https',
  'X-Forwarded-Ssl' => 'on'
}

gitlab_rails['gitlab_shell_ssh_port'] = 32222

registry_external_url 'https://reg.gitlab.dev.davar.com'

gitlab_rails['registry_enabled'] = true

registry_nginx['listen_port'] = 5050
registry_nginx['listen_https'] = false
registry_nginx['proxy_set_headers'] = {
  'X-Forwarded-Proto' => 'https',
  'X-Forwarded-Ssl' => 'on'
}

prometheus['monitor_kubernetes'] = false
```

### Ingress

The Kubernetes Ingress manifest [./k8s/1000-gitlab/50-ingress.yml.PRODUCTION](./k8s/1000-gitlab/50-ingress.yml.PRODUCTION) sets up Traefik to direct requests to the host **gitlab.dev.davar.com** to backend [Service] named **gitlab**.

```bash
kubectl apply -f ./k8s/1000-gitlab/50-ingress.yml.PRODUCTION
```

## Login

Browse to https://gitlab.dev.davar.com (replace top-level domain with your domain). **NOTE:** New Gitlab installs present a screen to set the admin (**root**) user's password. **Do this immediately** to prevent someone else from setting up Gitlab for you. 

## Note

Remember to keep the directory `/srv/gitlab` on the server backed up. 
 

## Connect GitLab with existing k8s cluster 

Ref: https://docs.gitlab.com/ee/user/project/clusters/add_remove_clusters.html

### Create GitLab group

GitLab Group Kubernetes Access
Although GitLab’s Kubernetes integration is based on trusting developers,
not all projects/repositories, or developers, need access to Kubernetes.
GitLab allows individual projects or groups to each have individually
integrated Kubernetes clusters.
Setting up a new GitLab group and integrates it with the existing k8s cluster.

[ Create GitLab group]

<img src="https://raw.githubusercontent.com/adavarski/k3s-gitlab-development/main/pictures/k3s-gitlab-create-group.png?raw=true" width="550">
 

# Configure Kubernetes Cluster Integration
Configure the new Data GitLab group to control a Kubernetes
cluster:
1. Select Kubernetes on left-side menu of the group.

2. Choose the tab Add Existing Cluster.

3. Provide a name for the cluster.

4. Provide the fully qualified URL to the Kubernetes
API exposed on the master node (e.g., https://
n1.dev2.davar.com:6443). Get URL example: 

```
kubectl cluster-info | grep 'Kubernetes master' | awk '/http/ {print $NF}'
```
5. Provide the cluster CA Certificate. The certificate
is easily found in the default-token in the default
Namespace. To retrieve the certificate in the
required PEM format, first list the Secrets in the
default Namespace: kubectl get secrets. If this is
a new cluster, the default-token will likely be the
only Secret. Use the following command, replacing
the <secret name> with the default-token:
  
`$ kubectl get secret $(kubectl get secret | grep default-token | awk '{print $1}') -o jsonpath="{['data']['ca\.crt']}" | base64 --decode`

Example:
```
$ kubectl get secret default-token-hw9pc -o jsonpath="{['data']['ca\.crt']}" | base64 --decode
-----BEGIN CERTIFICATE-----
MIIBdzCCAR2gAwIBAgIBADAKBggqhkjOPQQDAjAjMSEwHwYDVQQDDBhrM3Mtc2Vy
dmVyLWNhQDE2MDU4NTIxNzcwHhcNMjAxMTIwMDYwMjU3WhcNMzAxMTE4MDYwMjU3
WjAjMSEwHwYDVQQDDBhrM3Mtc2VydmVyLWNhQDE2MDU4NTIxNzcwWTATBgcqhkjO
PQIBBggqhkjOPQMBBwNCAAR2CLW6dHK4Ruf/2QicowBm4RzIRI+ySJVzNXVHtmGV
o4EZiwgrNBps+ke6HlqBeK5VBP+N5GbjvHOKeC6SsI8Ro0IwQDAOBgNVHQ8BAf8E
BAMCAqQwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUh/vE0AYWkvjLgWqF0ecS
6NdJuJ0wCgYIKoZIzj0EAwIDSAAwRQIhAJf+BzwbSh0bi7etJHBZiG7WhoOiCGhE
qS3MHWAxlZmFAiAH20c8ORqdlIRbrtcJZ2ZGtl5ZNZ2sMQoK4ChkMHBPhQ==
-----END CERTIFICATE-----
```
6.Setup gitlab-admin @ existing k8s cluster

```
$ cat gitlab-admin-service-account.yaml 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: gitlab-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: gitlab
    namespace: kube-system
```
and apply :

`$ kubectl apply -f gitlab-admin-service-account.yaml`

7. Provide the Service Token from the gitlab-admin
service account set up on existing k8s. Use
the following command:

`kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep gitlab | awk '{print $1}')`

Example:
```
$ kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep gitlab | awk '{print $1}')
Name:         gitlab-token-9x6fv
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: gitlab
              kubernetes.io/service-account.uid: c535a375-a105-45a2-ab10-4c662910d51d

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     570 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6Ik9odGhfSHRzQ1NiM1ZQSVRQZlQ2NUJQRDFVN2FMOVNIWVpFWS15VktvTXMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJnaXRsYWItdG9rZW4tOXg2ZnYiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZ2l0bGFiIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYzUzNWEzNzUtYTEwNS00NWEyLWFiMTAtNGM2NjI5MTBkNTFkIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmdpdGxhYiJ9.GZxg2j51zoP_W0D8v5nT3sbesY49AqyneeXFjavCw_2mPR0_D7mWifBorCEonYTdJNUfG1QXZEbvlRiNgvmtnuiRnl7U5NkeIOfRoRKnM27QqYjgg1qYhi3M8OxCU8HfaWwSoiom-n4om5KWIp6awIgUiHVapErV37gsZpJQERO_16dxtkgpPZ5kh7ZJvoB7vx1rDfBMjUUM8XVyZmjTk-aXA0B9TnNBKKRCz4tuK73fhi0N1TfLrlq4TpyBox9ISV60wFY-i26lBCz7iFpqToIZ3VroCB5sI0vY1I6qDfBTWvesMJrMN9YUMmzZYlz7dBjZQqUNB9EXarpZxHO3Aw

```

8. Ensure that RBAC is enabled.

[GitLab group Kubernetes configuration menu]

<img src="https://raw.githubusercontent.com/adavarski/k3s-gitlab-development/main/pictures/k3s-gitlab-add-existing-cluster.png?raw=true" width="750">
 

Note: If you want to add k8s k3s-based cluster where gitlab is running because of error "https://dev-k3s.davar.com:6443
is blocked: Requests to the local network are not allowed": 

```
Log in to gitlab with the admin account,
Click "settings" -> "network" -> "Outbound requests"
Check the box labeled "Allow requests to the local network from web hooks and services"
Click "Save changes"
```


### Enable Dependencies

1.Provide a base domain. Although unused in this
chapter, GitLab can use this base domain for Auto
DevOps 7 and Knative 8 integration.

2.Install Helm Tiller. GitLab installs Helm into a new
Namespace called gitlab-managed-apps on the
cluster. GitLab manages its dependent applications
behind the scenes with Helm charts. Helm Tiller may
already be installed in the cluster and running in
another namespace; however, GitLab requires its own
Helm Tiller. Installation may take several minutes. The
newly released Helm 3 does not require Helm Tiller,
check GitLab documentation for the version installed.

3.Lastly, install the GitLab Runner (for
building custom containers with GitLab CI for example). 
Installation may take several minutes.


#### Note1: Alternatively you can install GitLab HELM chart (K3S+Gitlab for k8s development):

- Install [k3sup](https://github.com/alexellis/k3sup) on your local computer.
- Install k3s on a server via the command (replace ip.add.re.ss with the
   server's IP address):
   `k3sup install --ip ip.add.re.ss --k3s-extra-args '--no-deploy=servicelb --no-deploy=traefik'`.
- Once that completes, set your env to read the `kubeconfig` file using the
   command: `export KUBECONFIG=$(pwd)/kubeconfig`
- Setup [Local Path Provisioner](https://github.com/rancher/local-path-provisioner/tree/master/).
- Mark the `local-path` StorageClass as default using the command:
   `kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'`
- Create the `metallb-system` namespace using the command
   `kubectl create ns metallb-system`.
- Create the `metallb-system/config` ConfigMap using the command
   `kubectl apply -f metallb-config.yaml`. For more information on the contents
   of this file, see [metallb documentation](https://metallb.universe.tf/).
- Setup [metallb](https://metallb.universe.tf/) using the command
   `kubectl apply -f metallb.yaml`.
- [Prepare Helm for RBAC](https://docs.gitlab.com/charts/installation/tools.html#preparing-for-helm-with-rbac)
- Setup the `base.yaml` and `values.yaml` files. For the `base.yaml` file, we
   recommend going with 
   [GKE minimum example](https://gitlab.com/gitlab-org/charts/gitlab/blob/master/examples/values-gke-minimum.yaml)
   and setting gitlab.task-runner.enabled to `true`. For the `values.yaml` file,
   you need to set the global.hosts.externalIP values to the IP address of your
   server.
   `curl --output values.yaml "https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-minikube-minimum.yaml"`
   `curl --output values.yaml "https://gitlab.com/gitlab-org/charts/gitlab/raw/master/examples/values-gke-minimum.yaml"`
- Install the GitLab helm chart repo using the command
   `helm repo add gitlab https://charts.gitlab.io/`.
- Update the GitLab helm chart repo using the command `helm repo update`.
- Deploy GitLab via helm using the command
   `helm install gitlab/gitlab -n gitlab -f base.yaml -f values.yaml`.
- Check the status of the deployment via `helm status gitlab`. Once everything
   is up and the external IP is allocated, you should be able to access your
   GitLab install.


For reference, this is the metal-config.yml:

```
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 165.22.38.200-165.22.38.200
```

If you use the above, remember to replace the values under `addresses` to match
the IP range your metallb setup is going to use.

#### Note2: GitLab can be integrated (Add existing k8s cluster) with kubernetes versions < v1.18

GitLab supports (october.2020) the following Kubernetes versions (check suported versions: https://docs.gitlab.com/ee/user/project/clusters/), and you can upgrade your Kubernetes version to any supported version at any time:
```
1.17
1.16
1.15
1.14 (deprecated, support ends on December 22, 2020)
1.13 (deprecated, support ends on November 22, 2020)
```
The helm tiller can't be installed in kubernetes v1.18.+ because is not supported Gitlab versions (helm tiller install issue, and helm is needed for all the other GitLab sub apps depend on Helm Tiller: you cannot use cert manager, ingress, etc.) :

```
$ kubectl get pod -n gitlab-managed-apps
NAME           READY   STATUS   RESTARTS   AGE
install-helm   0/1     Error    0          18h
$ kubectl logs install-helm -n gitlab-managed-apps
+ helm init --tiller-tls --tiller-tls-verify --tls-ca-cert /data/helm/helm/config/ca.pem --tiller-tls-cert /data/helm/helm/config/cert.pem --tiller-tls-key /data/helm/helm/config/key.pem --service-account tiller
Creating /root/.helm 
Creating /root/.helm/repository 
Creating /root/.helm/repository/cache 
Creating /root/.helm/repository/local 
Creating /root/.helm/plugins 
Creating /root/.helm/starters 
Creating /root/.helm/cache/archive 
Creating /root/.helm/repository/repositories.yaml 
Adding stable repo with URL: https://kubernetes-charts.storage.googleapis.com 
Adding local repo with URL: http://127.0.0.1:8879/charts 
$HELM_HOME has been configured at /root/.helm.
Error: error installing: the server could not find the requested resource
```

#### Example1: Integrate gitlab+k3s with existing k8s cluster (minikube k8s cluster running locally on your laptop):

```
# Install minikube and kubectl the same k8s minor version : v1.16.2 (Note: some GitLab supported k8s version) 
$ curl -Lo minikube https://github.com/kubernetes/minikube/releases/download/v1.5.2/minikube-linux-amd64 && chmod +x minikube && sudo mv ./minikube /usr/local/bin/
$ curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.2/bin/linux/amd64/kubectl && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl-minikube

# Run minikube and wait 
$ minikube start --cpus 2 --memory 4096
$ cd k8s/utils
$ cat gitlab-admin-service-account.yaml 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: gitlab-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: gitlab
    namespace: kube-system
    
$ kubectl-minikube create -f gitlab-admin-service-account.yaml 
serviceaccount/gitlab created
clusterrolebinding.rbac.authorization.k8s.io/gitlab-admin created   

$ kubectl-minikube cluster-info | grep 'Kubernetes master' | awk '/http/ {print $NF}'
https://192.168.99.102:8443

$ kubectl-minikube get secret $(kubectl-minikube get secret | grep default-token | awk '{print $1}') -o jsonpath="{['data']['ca\.crt']}" | base64 --decode
-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBATANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwptaW5p
a3ViZUNBMB4XDTIwMTExNjIzMTQ0MFoXDTMwMTExNTIzMTQ0MFowFTETMBEGA1UE
AxMKbWluaWt1YmVDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOjO
8JnDb7xLQ8UNGeQ81V8AWeuLOvuM9Bf45cY95pIllsOajPZeihSKbwyIGlewonrq
cT6a1temY3/xz5kvQIXoAnhTcpRpBr+ABrDr7OlJV8auSavkBj3XIBl80qycHY2H
slwPzX3u45bvhFwUnuUbRuFboLc4XTTRumN/V64iWIor7mkZEXNq1dBrLLdd51o9
U61DNOIfhMXOnusJDA8sxcIerxyzoFMysJghId6yDg2AUHIIBqCtEWmJMdDlxyBc
x3cREwqLDkez2+w1+cHazoVRPDhiPkN+28+tVKPZ9p4zKdwLdkQ+YccA0+LHP0VM
AiN71ObiJB1wwGeUKlMCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgKkMB0GA1UdJQQW
MBQGCCsGAQUFBwMCBggrBgEFBQcDATAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3
DQEBCwUAA4IBAQBptuv1zpxDGo4iik+rRgI49TpldkCBLuYnM100ZcudmQKCd4xv
bFpyZivNd/DgfCg0JgI6O4Ousz97MqjkgY8itdMsmiaPYKbBjwFMOL2Ly38t8PVA
U0ErF2R+aoTo6NjQJzqt/jCPOgIUGJv73S/9ajl9z0/bOHwQl0qz78OQkaRfg/Wv
feZW0kLi8+d4EyNIrF57jLuwxpyAwUC5oySkj0IZZYf8qeq6Y7o0i07c9RrpNDl6
r2jFQm0MsJZB8egFZSEMPwPhdj0zdIdv29YezNli8AuDa+7+u7/i9exncmiHR8r7
Gn1ytp/St1cV1OGnrVgK1gk0Mz4FRuC9/03v
-----END CERTIFICATE-----

$ kubectl-minikube -n kube-system describe secret $(kubectl-minikube -n kube-system get secret | grep gitlab | awk '{print $1}')
Name:         gitlab-token-w9n9b
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: gitlab
              kubernetes.io/service-account.uid: d006bf21-4f5a-4931-80e9-45c9aad73a07

Type:  kubernetes.io/service-account-token

Data
====
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IjdySjlnOE85RmJMN1JXV0VVa1ZzbmdMYWYxQlM4NVZRS2J5Y3l5RDJ1Rm8ifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJnaXRsYWItdG9rZW4tdzluOWIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZ2l0bGFiIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiZDAwNmJmMjEtNGY1YS00OTMxLTgwZTktNDVjOWFhZDczYTA3Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmdpdGxhYiJ9.HRCpdHUY0rAfU1fOebj1VZk8IWcyO9XIVOYOcwgXmL2L3-oKFP-al7OKv8WGTBSSkXF3fVg6av2O627t-Qx7olTl1fAeDBvdvKQQG9LgPDMELLQ4sSAi9tw_kcu3BQDz9OHgTs58RmxkWhtxGtUzgP37IpN2KfaoMEgoqpOIre94ssEAvOeNupZ2T2STaHFILg2FBiOq8meQyAsu9pU76-Tuny9jye2uYoAWDVFG5GvDCkAQnK6jm1uhnI3Go9E-2MT_DYGpWhfaweQ9TNS6B4aVguEB-FbTzfYwkJDWwFGuO-UWV24SOGGBtOmLIbVAeWIz04qNExqHZZbu5OLthQ
ca.crt:     1066 bytes

### Open https://gitlab.dev.davar.com/ and create k8s-development group for example, 
and integrate group k8s minikube cluster providing above: API URL (https://192.168.99.102:8443), CA Certificate and Service Token. 
Install Helm, GitLab Runner, etc.

```
#### Example2: Integrate gitlab+k3s with existing k8s cluster (k3s cluster:singel-node running on cloud VM or some bare-metal LAB server):

```
$ export INSTALL_K3S_VERSION=v1.16.10+k3s1
$ export K3S_CLUSTER_SECRET=$(head -c48 /dev/urandom | base64)
# copy the echoed secret
$ echo $K3S_CLUSTER_SECRET
Install k3s:
$ curl -sfL https://get.k3s.io | sh -s – server
Download the k3s kubectl config file to a local workstation:
$ scp root@VM_PUBLIC_IP_OR_BARE_METAL_IP:/etc/rancher/k3s/k3s.yaml  
~/.kube/k8s-c1
Edit the new config to point the c1 Kubernetes API along with naming
the cluster and contexts:
$ sed -i .bk "s/default/k8s-c1/" ~/.kube/k8s-c1
$ sed -i .bk "s/127.0.0.1/FQDN/" ~/.kube/k8s-c1 
# Example: sed -i .bk "s/127.0.0.1/sofia1-1.c1.example.com/" ~/.kube/k8s-c1
Use the new k8s-c1 config to work with the c1 cluster in a new
terminal on a location workstation:
$ export KUBECONFIG=~/.kube/k8s-c1

```
Note: For new k3s versions (k8s > 1.20)
```
$ ssh davar@192.168.1.22 -o IdentitiesOnly=yes
# hostnamectl set-hostname kmaster1
# curl -sfL https://get.k3s.io | sh -

Get K3S_TOKEN (stored at /var/lib/rancher/k3s/server/node-token on your k8s master server node).

To install on worker nodes and add them to the cluster, run the installation script with the K3S_URL and K3S_TOKEN environment variables. Here is an example showing how to join a worker node

Note: Each machine must have a unique hostname.

$ ssh davar@192.168.1.20 -o IdentitiesOnly=yes
# hostnamectl set-hostname kworker0
# curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.22:6443 K3S_TOKEN="K10073946490225175ee91bc5b1a042bf90c0a64e20cc250c6e47c1b8dbaf4ba4f9::server:eb7864f8e04971d7be27299f340fdeaf" sh -

$ ssh davar@192.168.1.21 -o IdentitiesOnly=yes
# hostnamectl set-hostname kworker1
# curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.22:6443 K3S_TOKEN="K10073946490225175ee91bc5b1a042bf90c0a64e20cc250c6e47c1b8dbaf4ba4f9::server:eb7864f8e04971d7be27299f340fdeaf" sh -

```        
        
#### Example3: Integrate gitlab+k3s with existing k3s Hybrid Cloud 

k3s multi-node Hybrid cluster running on cloud VMs on differen Cloud providers (different regions), based on Kilo pod network. 

Example bellow use Hybrid k3s multi-node installation: Master on Cloud_Provider_1 (Digital Ocean for example) and Workers on different Cloud_Provider_2 (Linode for example), all Workers running in the same Cloud_Provider_2 Region:

```
# DNS setup: Setup DNS to manage the DNS A entries for a new development cluster called c2: *.c2 points to
the IP addresses assigned to the cloud VM instances used as worker nodes, because we use DNS round-robin but not LoadBalancer for simplicity of DEV k8s environment

# Master Node (Ubuntu)
Log in to new cloud server instance, and upgrade and install
required packages along with WireGuard :

$ apt upgrade -y
$ apt install -y apt-transport-https \
ca-certificates gnupg-agent \
software-properties-common
$ add-apt-repository -y ppa:wireguard/wireguard
$ apt update
$ apt -o Dpkg::Options::=--force-confnew \
install -y wireguard

$ export INSTALL_K3S_VERSION=v1.16.10+k3s1
$ export K3S_CLUSTER_SECRET=$(head -c48 /dev/urandom | base64)
# copy the echoed secret
$ echo $K3S_CLUSTER_SECRET
Install k3s without the default Flannel Pod network; Kilo, installed later
in this chapter, will handle the layer-3 networking:
$ curl -sfL https://get.k3s.io | \
sh -s - server --no-flannel
# Taint the master
node to prevent the scheduling of regular workloads:
$ kubectl taint node master dedicated=master:NoSchedule
# Kilo creates VPN tunnels between regions using the name label topology.kubernetes.io/region; label the master node with its region,
in this example, nyc3:
$ kubectl label node master \
topology.kubernetes.io/region=nyc3
# Copy the k3s kubectl configuration file located at /etc/rancher/k3s/k3s.yaml to root home:
$ cp /etc/rancher/k3s/k3s.yaml ~
# Create a DNS entry for the master node, in this case, master.c2.
example.com, and update the copied ~/k3s.yml file with the new public
DNS. 
$ sed -i "s/127.0.0.1/master.c2.example.com/" k3s.yaml
$ sed -i "s/default/k8s-c2/" k3s.yaml
# copy the modified k3s.yaml onto a local workstation with
kubectl installed. From a local workstation, use secure copy:
$ scp root@master.c2.example.com:~/k3s.yaml ~/.kube/k8s-c2
Use the new kubectl configuration file to query the master node:
$ export KUBECONFIG=~/.kube/k8s-c2
$ kubectl describe node master

#Worker Nodes
# Log in to each new cloud server instance, and upgrade and install
required packages along with WireGuard on each instance:
$ apt upgrade -y
$ apt install -y apt-transport-https \
ca-certificates gnupg-agent \
software-properties-common
# Install kernel headers (if missing on instances)
$ apt install -y linux-headers-$(uname -r)
# Ceph block device kernel module (for Ceph support)
$ modprobe rbd
$ add-apt-repository -y ppa:wireguard/wireguard
$ apt update
$ apt -o Dpkg::Options::=--force-confnew \
install -y wireguard
# install k3s on each new Hetzner instance. Begin by populating
the environment variables K3S_CLUSTER_SECRET, the cluster secret
generated on the master node in the previous section, and K3S_URL, the
master node address, in this case master.c2.example.com. Pipe the k3s
installer script to sh along with the command-line argument agent (run as
nonworker) and a network topology label:
$ export INSTALL_K3S_VERSION=v1.16.10+k3s1
$ export K3S_CLUSTER_SECRET="<PASTE VALUE>"
$ export K3S_URL="https://master.example.com:6443"
$ curl -sfL https://get.k3s.io | \
sh -s - agent --no-flannel \
--node-label=\"topology.kubernetes.io/region=nbg1\"
# The c2.example.com cluster now consists of four nodes, one master
node and three worker nodes at different cloud providers. On a local
workstation with the kubectl configuration file copy and modified list the four nodes:
$ export KUBECONFIG=~/.kube/k8s-c2
$ kubectl get nodes -o wide
# kubectl lists four nodes in the cluster. The cluster lacks a Pod network
and will therefore report a NotReady status for each node.
# Node Roles setup 
$ kubectl label node nbg1-n1 kubernetes.io/role=worker
$ kubectl label node nbg1-n2 kubernetes.io/role=worker
$ kubectl label node nbg1-n3 kubernetes.io/role=worker
# Install Kilo 
# Kilo requires access to the kubectl config for each node in the
cluster to communicate with the master node. The kilo-k3s.yaml applied
requires the kubectl config /etc/rancher/k3s/k3s.yaml on each node. The
master node k3s install generated the file /etc/rancher/k3s/k3s.yaml.
Download, modify, and distribute this file to the same path on all worker
nodes (it does not need modification on the master node):
$ ssh root@master.c2.example.com \
sed "s/127.0.0.1/master.c2.example.com/" \ /etc/rancher/k3s/k3s.
yaml >k3s.yaml
Copy the modified k3s.yaml to /etc/rancher/k3s/k3s.yaml on each
node.
Finally, install Kilo by applying the kilo-k3s.yaml configuration
manifest:
$ kubectl apply -f \
https://raw.githubusercontent.com/squat/kilo/master/manifests/
kilo-k3s.yaml
# A Kilo agent is now running on each node. Once Kilo has completed the VPN setup, each node reports as Ready, and
the new c2 hybrid cluster is ready for use.
```

#### Note3: You can install GitLab HELM chart on minikube DEV environment (minikube+gitlab for k8s development):

Howtos:

https://docs.gitlab.com/ee/administration/troubleshooting/kubernetes_cheat_sheet.html
https://docs.gitlab.com/charts/development/minikube/index.html

### Note4: GitOps

New concepts like GitOps aim to completely manage the active configuration state directly with Git. GitOps, a process popularized by Weaveworks, is another trending concept within the scope of Kubernetes CI/CD. GitOps involves the use of applications reacting to git push events. GitOps focuses primarily on Kubernetes clusters matching the state described by configuration (www.weave.works/technologies/gitops/ ; www.gitops.tech/) residing in a Git repository. On a simplistic level, GitOps aims to replace kubectl apply with git push. Popular and well-supported GitOps implementations include ArgoCD, Flux, and Jenkins X, GitLAb. GitLab k8s integration supports GitOps.

### References:
```        
[Pod]:https://kubernetes.io/docs/concepts/workloads/pods/pod/
[Deployment]:https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
[Ingress]:https://kubernetes.io/docs/concepts/services-networking/ingress/
[Namespace]:https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
[Service]:https://kubernetes.io/docs/concepts/services-networking/service/
[Let's Encrypt]:https://letsencrypt.org/
[ClusterIssuer]:https://docs.cert-manager.io/en/latest/tasks/issuers/
[Traefik]:https://traefik.io/
[contexts]:https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
[kubectl]:https://kubernetes.io/docs/tasks/tools/install-kubectl/
[k3s]:https://k3s.io/
[Gitlab]:https://about.gitlab.com/
[Digital Ocean]:https://m.do.co/c/97b733e7eba4
[Linode]:https://www.linode.com/?r=848a6b0b21dc8edd33124f05ec8f99207ccddfde
[Kubernetes]:https://kubernetes.io/
```



