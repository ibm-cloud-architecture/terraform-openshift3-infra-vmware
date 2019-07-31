####################################
#### vSphere Access Credentials ####
####################################
variable "vsphere_server" {
    description = "vsphere server to connect to"
}

# Set username/password as environment variables VSPHERE_USER and VSPHERE_PASSWORD
variable "allow_unverified_ssl" {
    description = "Allows terraform vsphere provider to communicate with vsphere servers with self signed certificates"
    default     = "true"
}

##############################################
##### vSphere deployment specifications ######
##############################################
variable "vsphere_datacenter" {
    description = "Name of the vsphere datacenter to deploy to"
}

variable "vsphere_cluster" {
    description = "Name of vsphere cluster to deploy to"
}

variable "vsphere_resource_pool" {
    description = "Path of resource pool to deploy to. i.e. /path/to/pool"
    default     = "/"
}

variable "network_label" {
    description = "Name or label of network to provision VMs on. All node VMs will be provisioned on the same network"
}

variable "bastion_network_label" {
    description = "Name or label of network to provision the bastion VMs on."
}

variable "datastore" {
    description = "Name of datastore to use for the VMs"
}

variable "datastore_etcd" {
    description = "Name of datastore to use for the ETCD on the Master nodes"
    default     = ""
}

## Note
# Because of https://github.com/terraform-providers/terraform-provider-vsphere/issues/271 templates must be converted to VMs on ESX 5.5 (and possibly other)
variable "template" {
    description = "Name of template or VM to clone for the VM creations. Tested on Ubuntu 16.04 LTS"
}

variable "folder" {
    description = "Name of VM Folder to provision the new VMs in. The folder will be created"
}

variable "instance_name" {
    description = "Name of the ICP installation, will be used as basename for VMs"
}

variable "domain" {
    description = "Specify domain name to be used for linux customization on the VMs, or leave blank to use <instance_name>.icp"
}

variable "bastion_staticipblock" {
    description = "Specify start unused static ip cidr block to assign IP addresses to the cluster, e.g. 172.16.0.0/16.  Set to 0.0.0.0/0 for DHCP."
    default     = "0.0.0.0/0"

}

variable "staticipblock" {
    description = "Specify start unused static ip cidr block to assign IP addresses to the cluster, e.g. 172.16.0.0/16.  Set to 0.0.0.0/0 for DHCP."
    default     = "0.0.0.0/0"
}

variable "bastion_staticipblock_offset" {
    description = "Specify the starting offset of the staticipblock to begin assigning IP addresses from.  e.g. with staticipblock 172.16.0.0/16, offset of 10 will cause IP address assignment to begin at 172.16.0.11."
    default     = 0
}

variable "staticipblock_offset" {
    description = "Specify the starting offset of the staticipblock to begin assigning IP addresses from.  e.g. with staticipblock 172.16.0.0/16, offset of 10 will cause IP address assignment to begin at 172.16.0.11."
    default     = 0
}

variable "gateway" {
    description = "Default gateway for the newly provisioned VMs. Leave blank to use DHCP"
    default     = ""
}

variable "bastion_gateway" {
    description = "Default gateway for the newly provisioned VMs. Leave blank to use DHCP"
    default     = ""
}

variable "netmask" {
    description = "Netmask in CIDR notation when using static IPs. For example 16 or 24. Set to 0 to retrieve from DHCP"
    default     = 0
}

variable "bastion_netmask" {
    description = "Netmask in CIDR notation when using static IPs. For example 16 or 24. Set to 0 to retrieve from DHCP"
    default     = 0
}

variable "dns_servers" {
    description = "DNS Servers to configure on VMs"
    default     = ["8.8.8.8", "8.8.4.4"]
}

variable "bastion_dns_servers" {
    description = "DNS Servers to configure on VMs"
    default     = ["8.8.8.8", "8.8.4.4"]
}

variable "cluster_lb_address" {
    description = "External LoadBalancer address for Master Console"
    default     = "none"
}

variable "infra_lb_address" {
    description = "External Load Balancer address for infra Node"
    default     = "none"
}

#################################
##### ICP Instance details ######
#################################
variable "bastion" {
    type = "map"

    default = {
        nodes  = "1"
        vcpu   = "2"
        memory = "8192"

        disk_size             = ""      # Specify size or leave empty to use same size as template.
        datastore_disk_size   = "50"    # Specify size datastore directory, default 50.
        thin_provisioned      = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
        eagerly_scrub         = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
        keep_disk_on_remove   = "false" # Set to 'true' to not delete a disk on removal.

        start_iprange = "" # Leave blank for DHCP, else masters will be allocated range starting from this address
    }
}

variable "master" {
  type = "map"

    default = {
    nodes  = "1"
    vcpu   = "8"
    memory = "16384"

    disk_size             = ""      # Specify size or leave empty to use same size as template.
    docker_disk_size      = "100"   # Specify size for docker disk, default 100.
    docker_disk_device    = ""
    datastore_disk_size   = "50"    # Specify size datastore directory, default 50.
    datastore_disk_device = ""
    datastore_etcd_size   = "50"    # Specify size etcd datastore directory, default 50.
    datastore_etcd_device = ""
    thin_provisioned_etcd = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
    thin_provisioned      = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
    eagerly_scrub         = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
    keep_disk_on_remove   = "false" # Set to 'true' to not delete a disk on removal.

    start_iprange = "" # Leave blank for DHCP, else masters will be allocated range starting from this address
  }
}

variable "infra" {
  type = "map"

    default = {
    nodes  = "1"
    vcpu   = "2"
    memory = "4096"

    disk_size           = ""      # Specify size or leave empty to use same size as template.
    docker_disk_size    = "100"   # Specify size for docker disk, default 100.
    docker_disk_device  = ""
    thin_provisioned    = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
    eagerly_scrub       = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
    keep_disk_on_remove = "false" # Set to 'true' to not delete a disk on removal.

    start_iprange = "" # Leave blank for DHCP, else proxies will be allocated range starting from this address
  }
}

variable "worker" {
  type = "map"

    default = {
    nodes  = "1"
    vcpu   = "4"
    memory = "16384"

    disk_size           = ""      # Specify size or leave empty to use same size as template.
    docker_disk_size    = "100"   # Specify size for docker disk, default 100.
    docker_disk_device  = ""
    thin_provisioned    = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
    eagerly_scrub       = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
    keep_disk_on_remove = "false" # Set to 'true' to not delete a disk on removal.

    start_iprange = "" # Leave blank for DHCP, else workers will be allocated range starting from this address
  }
}

variable "storage" {
  type = "map"

    default = {
    nodes  = "1"
    vcpu   = "8"
    memory = "16384"

    disk_size           = ""      # Specify size or leave empty to use same size as template.
    docker_disk_size    = "100"   # Specify size for docker disk, default 100.
    docker_disk_device  = ""
    gluster_disk_size   = ""
    gluster_disk_device = ""
    log_disk_size       = "50"    # Specify size for /opt/ibm/cfc for log storage, default 50
    thin_provisioned    = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
    eagerly_scrub       = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
    keep_disk_on_remove = "false" # Set to 'true' to not delete a disk on removal.

    start_iprange = "" # Leave blank for DHCP, else workers will be allocated range starting from this address
  }
}

variable "haproxy" {
    type = "map"

    default = {
        nodes  = "2"
        vcpu   = "2"
        memory = "8192"

        disk_size             = ""      # Specify size or leave empty to use same size as template.
        datastore_disk_size   = "50"    # Specify size datastore directory, default 50.
        thin_provisioned      = ""      # True or false. Whether to use thin provisioning on the disk. Leave blank to use same as template
        eagerly_scrub         = ""      # True or false. If set to true disk space is zeroed out on VM creation. Leave blank to use same as template
        keep_disk_on_remove   = "false" # Set to 'true' to not delete a disk on removal.

        start_iprange = "" # Leave blank for DHCP, else masters will be allocated range starting from this address
    }
}


variable "docker_package_location" {
    description = "URI for docker package location, e.g. http://<myhost>/icp-docker-18.03_x86_64.bin or nfs:<myhost>/icp-docker-18.03_x86_64.bin"
    default     = ""
}

variable "image_location" {
    description = "URI for image package location, e.g. http://<myhost>/ibm-cloud-private-x86_64-3.1.0.tar.gz or nfs:<myhost>/ibm-cloud-private-x86_64-3.1.0.tar.gz"
    default     = ""
}

variable "private_registry" {
    description = "Private docker registry where the ICP installation image is located"
    default     = ""
}

variable "registry_username" {
    description = "Username for the private docker restistry the ICP image will be grabbed from"
    default   = ""
}

variable "registry_password" {
    description = "Password for the private docker restistry the ICP image will be grabbed from"
    default   = ""
}

variable "registry_mount_src" {
    description = "Mount point containing the shared registry directory for /var/lib/registry"
    default     = ""
}

variable "registry_mount_type" {
    description = "Mount Type of registry shared storage filesystem"
    default     = "nfs"
}

variable "registry_mount_options" {
    description = "Additional mount options for registry shared directory"
    default     = "defaults"
}

variable "audit_mount_src" {
    description = "Mount point containing the shared registry directory for /var/lib/icp/audit"
    default     = ""
}

variable "audit_mount_type" {
    description = "Mount Type of registry shared storage filesystem"
    default     = "nfs"
}

variable "audit_mount_options" {
    description = "Additional mount options for audit shared directory"
    default     = "defaults"
}

variable "icppassword" {
    description = "Password for the initial admin user in ICP"
    default     = "admin"
}

variable "ssh_user" {
    description = "Username which terraform will use to connect to newly created VMs during provisioning"
    default     = "root"
}

variable "ssh_password" {
    description = "Password which terraform will use to connect to newly created VMs during provisioning"
    default     = ""
}

variable "ssh_keyfile" {
    description = "Location of private ssh key to connect to newly created VMs during provisioning"
    default     = "/dev/null"
}

variable "icp_inception_image" {
    description = "ICP image to use for installation"
    default     = "ibmcom/icp-inception-amd64:3.1.0-ee"
}

variable "network_cidr" {
    description = "Pod network CIDR"
    default     = "192.168.0.0/16"
}

variable "service_network_cidr" {
    description = "Service network CIDR"
    default     = "10.10.10.0/24"
}

variable "parallel_image_pull" {
    description = "Parallel Image Pull"
    default     = "false"
}

# The following services can be disabled for 3.1
# custom-metrics-adapter, image-security-enforcement, istio, metering, monitoring, service-catalog, storage-minio, storage-glusterfs, and vulnerability-advisor
variable "disabled_management_services" {
    description = "List of management services to disable"
    type        = "list"
    default     = ["istio", "vulnerability-advisor", "storage-glusterfs", "storage-minio"]
}


variable "bastion_ssh_key_file" {}
