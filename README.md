## Abstract
This article provide guidelines and considerations to provision the IBM Cloud Infrastructure to deploy a reference implementation of Red Hat® OpenShift Container Platform 3.

Refer to https://github.com/IBMTerraform/terraform-ibm-openshift/blob/master/docs/02-Deploy-OpenShift.md to Deploy & Manage the Red Hat® OpenShift Container Platform on IBM Cloud.

## Summary
Red Hat® OpenShift Container Platform 3 is built around a core of application containers, with orchestration and management provided by Kubernetes, on a foundation of Atomic Host and Red Hat® Enterprise Linux. OpenShift Origin is the upstream community project that brings it all together along with extensions, to accelerate application development and deployment.
This reference environment provides an example of how OpenShift Container Platform 3 can be set up to take advantage of the native high availability capabilities of Kubernetes and IBM Cloud in order to create a highly available OpenShift Container Platform 3 environment. The configuration consists of
* one OpenShift Container Platform *masters*,
* three OpenShift Container Platform *infrastructure nodes*,
* two OpenShift Container Platform *application nodes*, and
* native IBM Cloud Infrastructure services.

# Phase 1: Provision Infrastructure

This is meant to be used as a module, make sure your module implementation sets all the variables in its terraform.tfvars file

```terraform
module "infrastructure" {
  source = "git::ssh://git@github.ibm.com/ncolon/terraform-openshift-vmware.git"

  # source                       = "../git/terraform-openshift-vmware"
  vsphere_server               = "${var.vsphere_server}"
  vsphere_cluster              = "${var.vsphere_cluster}"
  vsphere_datacenter           = "${var.vsphere_datacenter}"
  vsphere_resource_pool        = "${var.vsphere_resource_pool}"
  network_label                = "${var.network_label}"
  bastion_network_label        = "${var.bastion_network_label}"
  datastore                    = "${var.datastore}"
  template                     = "${var.template}"
  folder                       = "${var.hostname_prefix}"
  instance_name                = "${var.hostname_prefix}"
  domain                       = "${var.domain}"
  bastion_staticipblock        = "${var.bastion_staticipblock}"
  bastion_staticipblock_offset = "${var.bastion_staticipblock_offset}"
  bastion_gateway              = "${var.bastion_gateway}"
  bastion_netmask              = "${var.bastion_netmask}"
  bastion_dns_servers          = "${var.bastion_dns_servers}"
  staticipblock                = "${var.staticipblock}"
  staticipblock_offset         = "${var.staticipblock_offset}"
  gateway                      = "${var.gateway}"
  netmask                      = "${var.netmask}"
  dns_servers                  = "${var.dns_servers}"
  ssh_user                     = "${var.ssh_user}"
  ssh_password                 = "${var.ssh_password}"
  bastion_ssh_key_file         = "${var.bastion_ssh_key_file}"
  master                       = "${var.master}"
  infra                        = "${var.infra}"
  worker                       = "${var.worker}"
  storage                      = "${var.storage}"
  bastion                      = "${var.bastion}"
  haproxy                      = "${var.haproxy}"
}
```

## Module Inputs Variables

|Variable Name|Description|Default Value|
|-------------|-----------|-------------|
|vsphere_server|vSphere Server FQDN/IP Address|-|
|vsphere_cluster|vSphere Cluter|-|
|vsphere_datacenter|vSphere Datacenter|-|
|vsphere_resource_pool|vSphere Resource Pool|-|
|network_label|Name of Network for OCP Nodes|-|
|bastion_network_label|Name of Network for Bastion Node|-|
|datastore|vSphere Datastore to deploy to|-|
|template|vSphere Template to use for deployments|-|
|folder|vSphere Folder to put all VMs under|-|
|instance_name|hostname prefix for VMs|-|
|domain|Custom Domain to use for OpenShift|-|
|bastion_staticipblock|CIDR for Bastion VM|`0.0.0.0/0` for DHCP|
|bastion_staticipblock_offset|Start using IPv4 Addresses on `bastion_staticipblock` after this number.  Ex: `bastion_staticipblock=192.168.0.0/24` with `bastion_staticipblock_offset=10` will assign `192.168.0.10` to the Bastion VM|-|
|bastion_gateway|IPv4 Gateway of Bastion VM|-|
|bastion_netmask|Netmask of Bastion VM|-|
|bastion_dns_servers|DNS Servers to use for Bastion VM|-|
|staticipblock|CIDR for OpenShift Nodes|`0.0.0.0/0` for DHCP|
|staticipblock_offset|Same as `bastion_staticipblock` but for OpenShift Nodes|-|
|gateway|Gateway for OpenShift Nodes|-|
|netmask|Netmask for OpenShift Nodes|-|
|dns_servers|DNS Servers to use for OpenShift Nodes|-|
|ssh_user|SSH user.  Must have passwordless sudo access|-|
|ssh_password|Password for `ssh_user`.  Only used here to copy ssh keys to vms|-|
|bastion_ssh_key_file|Private SSH Key for VM access|-|
|bastion|A map variable for configuration of Bastion node|See sample variables.tf|
|master|A map variable for configuration of Master nodes|See sample variables.tf|
|infra|A map variable for configuration of Infra nodes|See sample variables.tf|
|worker|A map variable for configuration of Worker nodes|See sample variables.tf|
|storage|A map variable for configuration of Storage nodes|See sample variables.tf|
|haproxy|A map variable for configuration of HAProxy nodes|See sample variables.tf|


## Module Output
|Variable Name|Description|Type
|-------------|-----------|-------------|
|domain|Domain Name for the network interface used by VMs in the cluster.|string|
|bastion_public_ip|IPv4 address of Bastion VM|string|
|bastion_hostname|hostname of Bastion VM|string|
|master_private_ip|Provate IPv4 addresses of Master Node vms|list|
|master_hostname|hostnames of Master Node vms|list|
|infra_private_ip|Provate IPv4 addresses of Infra Node vms|list|
|infra_hostname|hostnames of Infra Node vms|list|
|app_private_ip|Provate IPv4 addresses of Application Node vms|list|
|app_hostname|hostnames of Application Node vms|list|
|storage_private_ip|Provate IPv4 addresses of Storage Node vms|list|
|storage_hostname|hostnames of Master Storage vms|list|
|haproxy_public_ip|Provate IPv4 addresses of HAProxy Node vms|list|
|haproxy_hostname|hostnames of HAProxy Storage vms|list|
|public_master_vip|FQDN of cluster master loadbalancer|string|
|public_app_vip|FQDN of cluster apps loadbalancer|string|


The infrastructure is provisioned using the terraform modules with the following configuration:

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

***Application nodes***

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
| HAProxy Nodes | os disk: 100Gb| var.haproxy["nodes"] |


## DNS Configuration

OpenShift Compute Platform requires a fully functional DNS server, and is properly configured wildcard DNS zone that resolves to the IP address of the OpenShift router. By default, *dnsmasq* is automatically configured on all masters and nodes to listen on port 53. The pods use the nodes as their DNS, and the nodes forward the requests.

You can use [terraform-openshift-dnscerts](https://github.ibm.com/ncolon/terraform-openshift-cloudflare) as a terraform module to provide DNS and certificates for your cluster

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

Take a look at [terraform-openshift-deploy](https://github.ibm.com/ncolon/terraform-openshift-deploy) to create your inventory file and deploy openshift.

----
