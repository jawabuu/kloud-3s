# kloud-3s - k3s in the cloud

kloud-3s is a set of [terraform](https://www.terraform.io/) modules that deploys a secure, functional ( kubernetes) [k3s](https://github.com/rancher/k3s) cluster on a number of cloud providers.  
The following are currently tested;
* [Hetzner Cloud](https://hetzner.cloud/?ref=AW4fux8AhdV8)
* [Vultr](https://www.vultr.com/?ref=8601755)
* [DigitalOcean](https://www.digitalocean.com/?refcode=661c567f71b1)
* [Linode](https://www.linode.com/?r=b402c474596a2d1656eac49aefe071916cbb2d61)
* [UpCloud](https://upcloud.com/signup/?promo=Q25K8M)
* [ScaleWay](https://www.scaleway.com/)
* [OVH](https://www.ovhcloud.com/en/public-cloud/)
* [Google Cloud](https://cloud.google.com/)
* [Azure](https://azure.microsoft.com/en-us/)
* [Amazon Web Services](https://aws.amazon.com/)
* [Alibaba Cloud](https://www.alibabacloud.com/)

You may support the project by using the referral links above.

This project is inspired by and borrows from the awesome work done by [Hobby-Kube](https://github.com/hobby-kube)  

Why kloud-3s?
---

kloud-3s follows the [hobby-kube guidelines](https://github.com/hobby-kube/guide) for setting up a secure kubernetes cluster.
As [this guide](https://github.com/hobby-kube/guide) is comprehensive, the information will not be repeated here.  
kloud-3s aims to add the following;

1. Use a LightWeight kubernetes distribution i.e. [k3s](https://github.com/rancher/k3s) .
1. Allow clean scale-up and scale down of nodes.
1. Improve supported OS'. kloud-3s supports Windows with git-bash.
1. Bootstrap installation with only minimal variables required.
1. Resolve cluster and pod networking issues that ranks as the most common issue for k3s installations. 
1. Support multiple kubernetes CNI's and support preservation of source IP's out of the box. The following have been tested;
    The embedded k3s flannel ([does not preserve source IP](https://github.com/rancher/k3s/issues/1652)).
    | CNI | Installation Docs |
    | ------ | ------ |
    | [Flannel](https://github.com/coreos/flannel) | https://coreos.com/flannel/docs/latest/kubernetes.html |
    | [Cilium](https://github.com/cilium/cilium) | https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/ |
    | [Calico](https://github.com/projectcalico/calico) | https://docs.projectcalico.org/getting-started/kubernetes/quickstart|
    | [Weave](https://github.com/weaveworks/weave) | https://www.weave.works/docs/net/latest/kubernetes/kube-addon/ |
1. Add testing by using some popular cloud-native projects, namely:
    * [traefik](https://github.com/containous/traefik)
    * [cert-manger](https://github.com/jetstack/cert-manager)
    * [metallb](https://github.com/metallb/metallb) 
    * [pomerium](https://github.com/pomerium/pomerium)
    * [vault](https://github.com/hashicorp/vault)

A successful deployment will complete without any error from these deployments.

Features
---
1. kloud-3s is opinionated and does not support every available use-case.
The objective is to provide a consistent deployment experience across the supported cloud providers.
1. For maximum portability kloud-3s does not use an ssh-agent for it's terraform modules. It does not require existing ssh-keys but users may define their existing key paths.
1. Enforce encrypted communication between nodes and use vpc/private networks if supported by cloud provider.
1. Although not required, kloud-3s suggests using it with a domain you own.
1. kloud-3s creates an `A record` and **wildcard** `CNAME record` of the domain value you provided pointing to your master node.
1. kloud-3s ensures functionality of the following across all its supported cloud providers. The support matrix will be updated as other versions are tested.

    | Software | Version |
    | ------ | ------ |
    | Ubuntu| 20.04 LTS|
    | K3S | v1.21.1+k3s1|
1. kloud-3s tests a successful deployment by using traefik and cert-manager deployments sending requests to the following endpoints;
    | Test | Response Code | Certificate Issuer |
    | ------ | ------ | ------ |
    |`curl -Lkv test.your.domain`|`200`|`None`|
    |`curl -Lkv whoami.your.domain`|`200`|`Fake LE`|
    |`curl -Lkv dash.your.domain`|`200`|`LetsEncrypt`|
Dependencies
---
kloud-3s requires the following installed on your system
* terraform
* wireguard
* jq
* kubectl
* git-bash if on Windows

Deployment
---

### Quick Install

1. Clone the repo
    ```sh
    $ git clone https://github.com/jawabuu/kloud-3s.git
    ```
1. Switch to desired cloud provider under the [deploy](./deploy) directory.
    For example, to deploy kloud-3s on digitalocean
    ```sh
    $ cd kloud-3s/deploy/digitalocean
    ```
1. Copy [tfvars.example](./deploy/digitalocean/tfvars.example) to terraform.tfvars
    ```sh
    deploy/digitalocean$ cp tfvars.example terraform.tfvars
    ```
1. Using your favourite editor, update values in terraform.tfvars marked required
    ```sh
    deploy/digitalocean$ nano terraform.tfvars
    
    # DNS Settings
    create_zone = "true"
    domain      = "kloud-3s.my.domain"
    # We are using digitalocean for dns
    # Resource Settings
    digitalocean_token    = <required>
    ```
1. Run `terraform init` to initalize modules
    ```sh
    deploy/digitalocean$ terraform init
    ```

1. Run `terraform plan` to view changes terraform will make 
    ```sh
    deploy/digitalocean$ terraform apply
    ```

1. Run `terraform apply` to create your resources
    ```sh
    deploy/digitalocean$ terraform apply --auto-approve
    ```

1. Set `KUBECONFIG` by running `$(terraform output kubeconfig)`
    ```sh
    deploy/digitalocean$ $(terraform output kubeconfig)
    ```

1. Check resources `kubectl get po -A -o wide`
    ```sh
    deploy/digitalocean$ kubectl get po -A -o wide
    NAMESPACE        NAME                                       READY   STATUS    RESTARTS   AGE   IP            NODE    NOMINATED NODE   READINESS GATES
    kube-system      cilium-operator-77d99f8578-hqhtx           1/1     Running   0          60s   10.0.1.2      kube2   <none>           <none>
    kube-system      metrics-server-6d684c7b5-nrphr             1/1     Running   0          20s   10.42.1.68    kube2   <none>           <none>
    kube-system      cilium-ggjxz                               1/1     Running   0          60s   10.0.1.2      kube2   <none>           <none>
    kube-system      coredns-6c6bb68b64-54dgw                   1/1     Running   0          33s   10.42.0.3     kube1   <none>           <none>
    kube-system      cilium-9t6f7                               1/1     Running   0          51s   10.0.1.1      kube1   <none>           <none>
    cert-manager     cert-manager-9b8969d86-4ppxb               1/1     Running   0          30s   10.42.0.8     kube1   <none>           <none>
    whoami           whoami-5c8d94f78-qg2pc                     1/1     Running   0          20s   10.42.1.217   kube2   <none>           <none>
    whoami           whoami-5c8d94f78-8bgtc                     1/1     Running   0          16s   10.42.0.231   kube1   <none>           <none>
    default          traefik-76695c9b69-t25j2                   1/1     Running   0          27s   10.42.0.94    kube1   <none>           <none>
    metallb-system   speaker-rwc46                              1/1     Running   0          8s    10.0.1.2      kube2   <none>           <none>
    metallb-system   controller-65c5689b94-vdcpn                1/1     Running   0          8s    10.42.1.90    kube2   <none>           <none>
    metallb-system   speaker-zmpnx                              1/1     Running   0          12h   10.0.1.1      kube1   <none>           <none>
    default          net-8c845cc87-vml5w                        1/1     Running   0          7s    10.42.1.52    kube2   <none>           <none>
    cert-manager     cert-manager-webhook-8c5db9fb6-b59tj       1/1     Running   0          28s   10.42.0.250   kube1   <none>           <none>
    kube-system      local-path-provisioner-58fb86bdfd-k7cfw    1/1     Running   4          34s   10.42.1.13    kube2   <none>           <none>
    cert-manager     cert-manager-cainjector-8545fdf87c-jddnl   1/1     Running   6          27s   10.42.0.219   kube1   <none>           <none>
    
    ```

1. SSH to master easily with `$(terraform output ssh-master)`
    ```sh
    deploy/digitalocean$ $(terraform output ssh-master)
    ```

### Advanced Install
For any given provider under the [deploy](deploy) directory, only the **terraform.tfvars** and **main.tf** files need to be modified.
Refer to the **variables.tf** file which contains information on the various variables that you can override in **terraform.tfvars**

<details>
<summary>Quick Reference</summary>

#### Quick References for readability

Common variables for deployment
|common variables|default|description|
|-|-|-|
|node_count|3|Number of nodes in cluster|
|create_zone|false|Create a domain zone if it does not exist|
|domain|none|Domain for the deployment|
|k3s_version|latest|This is set to v1.21.1+k3s1|
|cni|weave|Choice of CNI among default,flannel,cilium,calico,weave|
|overlay_cidr|10.42.0.0/16|pod cidr for k3s|
|vpc_cidr|10.115.0.0/24|vpc cidr for supported providers|
|ssh_key_path|`./../../.ssh/tf-kube`|Filepath for ssh private key|
|ssh_pubkey_path|`./../../.ssh/tf-kube.pub`|Filepath for ssh public key|
|ssh_keys_dir|`./../../.ssh`|Directory to store created ssh keys|
|kubeconfig_path|`./../../.kubeconfig`|Directory to store kubeconfig file|

Provider variables
| ************ | Authentication | Machine Size | Machine OS | Machine Region |
|-|-|-|-|-|
| **DigitalOcean** | digitalocean_token | digitalocean_size | digitalocean_image | digitalocean_region |
| **HetznerCloud** | hcloud_token | hcloud_type | hcloud_image | hcloud_location |
| **Vultr** | vultr_api_key | vultr_plan | vultr_os | vultr_region |
| **Linode** | linode_token | linode_type | linode_image | linode_region |
| **UpCloud** | upcloud_username, upcloud_password | upcloud_plan | upcloud_image | upcloud_zone |
| **ScaleWay** | scaleway_organization_id, scaleway_access_key, scaleway_secret_key | scaleway_type | scaleway_image | scaleway_zone |
| **OVH** | tenant_name, user_name, password | ovh_type | ovh_image | region |
| **Google** | creds_file | size | image | region, region_zone |
| **Azure** | client_id, client_secret, tenant_id, subscription_id | size | - | region |
| **AWS** | aws_access_key, aws_secret_key | size | image | region |
| **AlibabaCloud** | alicloud_access_key, alicloud_secret_key | size | - | scaleway_zone |
</details>

Todos
---

 - [ ] Support multi-master k3s HA clusters
 - [ ] Add module to optionally bootstrap basic logging, monitoring and ingress services in the vein of [kube-prod](https://github.com/bitnami/kube-prod-runtime) by bitnami.
 - [ ] Security hardening for production workloads
 - [ ] Support more cloud providers
 - [ ] Support more DNS providers
 - [ ] Add Cloud Controller Manager module
 - [ ] Implement K3S Auto upgrades


References
----
* https://github.com/xunleii/terraform-module-k3s
* https://github.com/hobby-kube/guide

License
----

[MIT](LICENSE.md)
