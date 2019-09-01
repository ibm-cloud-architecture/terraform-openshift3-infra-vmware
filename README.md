This terraform module creates VM infrastructure on VMware used to support an Openshift 3.x cluster.  Note that this is not the full platform, just the VMs.  This is meant to be used as a module, make sure your module implementation sets all the variables in its terraform.tfvars file.  You will need to layer additional infrastructure around the VMs (i.e. DNS, load balancers) before you install openshift.

## Usage example

Here is an example usage, please fill in with your real values:

```terraform
module "infrastructure" {
  source                       = "github.com/ibm-cloud-architecture/terraform-openshift3-infra-vmware"

  # vsphere information
  vsphere_server               = "<vsphere server URL>"
  vsphere_datacenter_id        = "<vsphere datacenter id>"
  vsphere_cluster_id           = "<vsphere cluster id>"
  vsphere_resource_pool_id     = "<vsphere resource pool id>"

  datastore_id                 = "<vsphere datastore id, leave blank if setting datastore_cluster_id using storage DRS>"
  datastore_cluster_id         = "<vsphere datastore cluster id, leave blank if setting datastore_id>"

  folder_path                  = "<folder path to put all VMs in>"

  instance_name                = "<hostname prefix for all VMs>"
  template                     = "<template name>"

  private_network_id           = "<private network label>"
  private_staticipblock        = "<cidr block of static IPs>" # e.g. 192.168.0.0/24
  private_staticipblock_offset = "<offset>"                   # for example, set to 0 and the first IP will be 192.168.0.1"
  private_netmask              = "<netmask>"                  # e.g. 24
  private_gateway              = "<private network gateway>"  
  private_domain               = "<private network domain>"   # added to the search suffix list
  private_dns_servers          = ["<dns1>", "<dns2>"]

  # optional parameters - if set, we will put the bastion host on the public network and use the public network IP to configure the other VMs
  public_network_id            = "<public network label>"
  public_staticipblock         = "<cidr block of static ips> # routable from the terraform VM, e.g. 172.16.0.0/24"
  public_staticipblock_offset  = "<offset>"                  # for example, set to 0 and the first IP will be 172.16.0.1
  public_gateway               = "<public network gateway>"  # becomes the default route for the bastion host
  public_netmask               = "<netmask>"                 # e.g. 24
  public_domain                = "<public network domain>"   # added to the search suffix list
  public_dns_servers           = ["<dns3>"]                  # added to nameserver

  # how to ssh into the template - must be able to passwordless sudo
  template_ssh_user            = "<ssh user>"
  template_ssh_private_key     = "<ssh private key>"

  # the keys to be added between bastion host and the VMs for passwordless SSH - best to generate these
  ssh_private_key              = "<ssh private key>"
  ssh_public_key               = "<ssh public key>"

  # information about VM types, see variables.tf for values to set
  master                       = "${var.master}"
  infra                        = "${var.infra}"
  worker                       = "${var.worker}"
  storage                      = "${var.storage}"
  bastion                      = "${var.bastion}"
}
```

## Module Output
|Variable Name|Description|Type
|-------------|-----------|-------------|
|bastion_private_ip|private IPv4 address of Bastion VM|string|
|bastion_public_ip|public IPv4 address of Bastion VM (or blank if none)|string|
|bastion_hostname|hostname of Bastion VM|string|
|master_private_ip|Provate IPv4 addresses of Master Node vms|list|
|master_hostname|hostnames of Master Node vms|list|
|infra_private_ip|Provate IPv4 addresses of Infra Node vms|list|
|infra_hostname|hostnames of Infra Node vms|list|
|app_private_ip|Provate IPv4 addresses of Application Node vms|list|
|app_hostname|hostnames of Application Node vms|list|
|storage_private_ip|Provate IPv4 addresses of Storage Node vms|list|
|storage_hostname|hostnames of Master Storage vms|list|

## Nodes

Nodes are VM_instances that serve a specific purpose for OpenShift Container Platform

***Master nodes***

* Contains the API server, controller manager server and etcd.
* Maintains the clusters configuration, manages nodes in its OpenShift cluster
* Assigns pods to nodes and synchronizes pod information with service configuration
* Used to define routes, services, and volume claims for pods deployed within the OpenShift environment.

***Infrastructure nodes***

* Used for the router and registry pods
* Optionally, used for Kibana / Hawkular metrics
* Recommends S3 storage for the Docker registry, which allows for multiple pods to use the same storage

***Worker/Application nodes***

* Runs non-infrastructure based containers
* Use block storage to persist application data; assigned to the pod using a Persistent Volume Claim.
* Nodes with the label app are nodes used for end user Application pods.
* Set a configuration parameter 'defaultNodeSelector: "role=app" on the master /etc/origin/master/master-config.yaml to ensures that OpenShift Container Platform user containers, will be placed on the application nodes by default.

**Bastion node:**

* The Bastion server provides a secure way to limit SSH access to the environment.
* The master and node security groups only allow for SSH connectivity between nodes inside of the Security Group while the Bastion allows SSH access from everywhere.
* The Bastion host is the only ingress point for SSH in the cluster from external entities. When connecting to the OpenShift Container Platform infrastructure, the bastion forwards the request to the appropriate server. Connecting through the Bastion server requires specific SSH configuration.

**Storage nodes:**

* Used for deploying Container-Native Storage for OpenShift Container Platform. This deployment delivers a hyper-converged solution, where the storage containers that host Red Hat Gluster Storage co-reside with the compute containers and serve out storage from the hosts that have local or direct attached storage to the compute containers. Each storage node is mounted with 3 block storage devices.

**Compute node configurations**

|nodes | details | count |
|------|---------|-------|
| Bastion Nodes | os disk: 100Gb | 1 |
| Master Node  | os disk: 100Gb<br>docker_disk : 100Gb | var.master["nodes"] |
| Infra Nodes | os disk: 100Gb<br>docker_disk : 100Gb | var.infra["nodes"] |
| Worker Nodes | os disk: 100Gb<br>docker_disk : 100Gb | var.worker["nodes"] |
| Storage Nodes | os disk: 100Gb<br>docker_disk : 100Gb<br>gluster_disk : 250GB | var.storage["nodes"] |


## DNS Configuration

OpenShift Compute Platform requires a fully functional DNS server, and is properly configured wildcard DNS zone that resolves to the IP address of the OpenShift router. By default, *dnsmasq* is automatically configured on all masters and nodes to listen on port 53. The pods use the nodes as their DNS, and the nodes forward the requests.

You can use [terraform-dns-cloudflare](https://github.com/ibm-cloud-architecture/terraform-dns-cloudflare) as a terraform module to provide DNS records for your cluster.

## Software Version Details
***RHEL OSEv3 Details***

|Software|Version|
|-------|--------|
|Red Hat® Enterprise Linux 7.4 x86_64| kernel-3.10.0.x|
|Atomic-OpenShift <br>{master/clients/node/sdn-ovs/utils} | 3.10.x.x |
|Docker|1.13.x|
|Ansible|2.7.x|

***Required Channels***

A subscription to the following channels is required in order to deploy this reference environment’s configuration.

You can use [terraform-openshift-rhnregister](https://github.ibm.com/ncolon/terraform-openshift-rhnregister) module to register your VMs with RHN

|Channel|Repository Name|
|-------|---------------|
|Red Hat® Enterprise Linux 7 Server (RPMs)|rhel-7-server-rpms|
|Red Hat® OpenShift Enterprise 3.10 (RPMs)|rhel-7-server-ose-3.10-rpms|
|Red Hat® Enterprise Linux 7 Server - Extras (RPMs)|rhel-7-server-extras-rpms|
|Red Hat® Enterprise Linux 7 Server - Fast Datapath (RPMs) |rhel-7-fast-datapath-rpms|


## Phase 2: Install OpenShift

Take a look at [terraform-openshift-deploy](https://github.com/ibm-cloud-architecture/terraform-openshift-deploy) to create your inventory file and deploy openshift.

----
