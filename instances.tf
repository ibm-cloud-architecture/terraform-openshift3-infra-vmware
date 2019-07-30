#################################
# Configure the VMware vSphere Provider
##################################
provider "vsphere" {
  version        = "~> 1.1"
  vsphere_server = "${var.vsphere_server}"

  # if you have a self-signed cert
  allow_unverified_ssl = "${var.allow_unverified_ssl}"

}

locals {
    private_ssh_key = "${file(var.bastion_ssh_key_file)}"
    public_key = "${var.bastion_ssh_key_file}.pub"
    public_ssh_key  = "${file(local.public_key)}"
}
##################################
#### Collect resource IDs
##################################
data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datastore" "datastore_etcd" {
  name          = "${var.datastore_etcd != "" ? var.datastore_etcd : var.datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}


data "vsphere_resource_pool" "pool" {
  name          = "${var.vsphere_cluster}/Resources/${var.vsphere_resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.network_label}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "bastion" {
  name          = "${var.bastion_network_label}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.template}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Create a folder
resource "vsphere_folder" "ocpenv" {
  count = "${var.folder != "" ? 1 : 0}"
  path = "${var.folder}"
  type = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}


locals  {
  folder_path = "${var.folder != "" ?
        element(concat(vsphere_folder.ocpenv.*.path, list("")), 0)
        : ""}"
}
##################################
#### Create the Bastion VM
##################################
resource "vsphere_virtual_machine" "bastion" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.bastion["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name      = "${format("${lower(var.instance_name)}-bastion-%02d", count.index + 1) }"
  num_cpus  = "${var.bastion["vcpu"]}"
  memory    = "${var.bastion["memory"]}"

  scsi_controller_count = 1
  scsi_type = "lsilogic-sas"

  ####
  # Disk specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-bastion-%02d.vmdk", count.index + 1) }"
    size             = "${var.bastion["disk_size"]        != "" ? var.bastion["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.bastion["eagerly_scrub"]    != "" ? var.bastion["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.bastion["thin_provisioned"] != "" ? var.bastion["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.bastion["keep_disk_on_remove"]}"
    unit_number      = 0
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  network_interface {
    network_id   = "${data.vsphere_network.bastion.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  ####
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${var.instance_name}-bastion"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }

      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }

      network_interface {
        ipv4_address  = "${var.bastion_staticipblock != "0.0.0.0/0" ? cidrhost(var.bastion_staticipblock, 1 + var.bastion_staticipblock_offset + count.index) : ""}"
        ipv4_netmask  = "${var.bastion_netmask}"
      }

      ipv4_gateway    = "${var.bastion_gateway}"
      dns_server_list = "${concat(var.bastion_dns_servers, var.dns_servers)}"
    }
  }

  # Specify the ssh connection
  connection {
    user          = "${var.ssh_user}"
    password      = "${var.ssh_password}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${local.public_ssh_key}\"",
      "/tmp/terraform_scripts/add-private-ssh-key.sh \"${local.private_ssh_key}\" \"${var.ssh_user}\"",
    ]
  }
}
##################################
#### Create the Master VM
##################################
resource "vsphere_virtual_machine" "master" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.master["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name      = "${format("${lower(var.instance_name)}-master-%02d", count.index + 1) }"
  num_cpus  = "${var.master["vcpu"]}"
  memory    = "${var.master["memory"]}"

  scsi_controller_count = 1
  scsi_type = "lsilogic-sas"

  ####
  # Disk specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-master-%02d.vmdk", count.index + 1) }"
    size             = "${var.master["disk_size"]        != "" ? var.master["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.master["eagerly_scrub"]    != "" ? var.master["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.master["thin_provisioned"] != "" ? var.master["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.master["keep_disk_on_remove"]}"
    unit_number      = 0
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-master-%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.master["docker_disk_size"]}"
    eagerly_scrub    = "${var.master["eagerly_scrub"]    != "" ? var.master["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.master["thin_provisioned"] != "" ? var.master["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.master["keep_disk_on_remove"]}"
    unit_number      = 1
  }


  disk {
    label            = "${format("${lower(var.instance_name)}-master-%02d_db.vmdk", count.index + 1) }"
    size             = "${var.master["datastore_disk_size"]}"
    eagerly_scrub    = "${var.master["eagerly_scrub"]    != "" ? var.master["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.master["thin_provisioned"] != "" ? var.master["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.master["keep_disk_on_remove"]}"
    unit_number      = 2
  }


  disk {
    datastore_id     = "${data.vsphere_datastore.datastore_etcd.id}"
    label            = "${format("${lower(var.instance_name)}-master-%02d_etcd.vmdk", count.index + 1) }"
    size             = "${var.master["datastore_etcd_size"]}"
    eagerly_scrub    = "${var.master["eagerly_scrub"]    != "" ? var.master["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.master["thin_provisioned_etcd"] != "" ? var.master["thin_provisioned_etcd"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.master["keep_disk_on_remove"]}"
    unit_number      = 3
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  ####
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${format("${lower(var.instance_name)}-master-%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + var.bastion["nodes"] + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }

      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  # Specify the ssh connection
  connection {
    user          = "${var.ssh_user}"
    password      = "${var.ssh_password}"
    bastion_host  = "${vsphere_virtual_machine.bastion.default_ip_address}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${local.public_ssh_key}\"",
    ]
  }
}
##################################
### Create the Infra VM
##################################
resource "vsphere_virtual_machine" "infra" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.infra["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name     = "${format("${lower(var.instance_name)}-infra-%02d", count.index + 1) }"
  num_cpus = "${var.infra["vcpu"]}"
  memory   = "${var.infra["memory"]}"


  ####
  # Disk specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-infra-%02d.vmdk", count.index + 1) }"
    size             = "${var.infra["disk_size"]        != "" ? var.infra["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.infra["eagerly_scrub"]    != "" ? var.infra["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.infra["thin_provisioned"] != "" ? var.infra["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.infra["keep_disk_on_remove"]}"
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-infra-%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.infra["docker_disk_size"]}"
    eagerly_scrub    = "${var.infra["eagerly_scrub"]    != "" ? var.infra["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.infra["thin_provisioned"] != "" ? var.infra["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.infra["keep_disk_on_remove"]}"
    unit_number      = 1
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  ####
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${format("${lower(var.instance_name)}-infra-%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }
      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + var.bastion["nodes"] + var.master["nodes"] + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }

      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  # Specify the ssh connection
  connection {
    user          = "${var.ssh_user}"
    password      = "${var.ssh_password}"
    bastion_host  = "${vsphere_virtual_machine.bastion.default_ip_address}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${local.public_ssh_key}\"",
    ]
  }
}
##################################
### Create the Worker VM
##################################
resource "vsphere_virtual_machine" "worker" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.worker["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name     = "${format("${lower(var.instance_name)}-worker-%02d", count.index + 1) }"
  num_cpus = "${var.worker["vcpu"]}"
  memory   = "${var.worker["memory"]}"


  #####
  # Disk Specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-worker-%02d.vmdk", count.index + 1) }"
    size             = "${var.worker["disk_size"]        != "" ? var.worker["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.worker["eagerly_scrub"]    != "" ? var.worker["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.worker["thin_provisioned"] != "" ? var.worker["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.worker["keep_disk_on_remove"]}"
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-worker-%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.worker["docker_disk_size"]}"
    eagerly_scrub    = "${var.worker["eagerly_scrub"]    != "" ? var.worker["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.worker["thin_provisioned"] != "" ? var.worker["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.worker["keep_disk_on_remove"]}"
    unit_number      = 1
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }


  #####
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${format("${lower(var.instance_name)}-worker-%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }

      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + var.bastion["nodes"] + var.master["nodes"] + var.infra["nodes"] + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }

      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  # Specify the ssh connection
  connection {
    user          = "${var.ssh_user}"
    password      = "${var.ssh_password}"
    bastion_host  = "${vsphere_virtual_machine.bastion.default_ip_address}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${local.public_ssh_key}\"",
    ]
  }
}
##################################
### Create the Storage VM
##################################
resource "vsphere_virtual_machine" "storage" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${local.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.storage["nodes"]}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"

  name     = "${format("${lower(var.instance_name)}-storage-%02d", count.index + 1) }"
  num_cpus = "${var.storage["vcpu"]}"
  memory   = "${var.storage["memory"]}"


  #####
  # Disk Specifications
  ####
  datastore_id  = "${data.vsphere_datastore.datastore.id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "${format("${lower(var.instance_name)}-storage-%02d.vmdk", count.index + 1) }"
    size             = "${var.storage["disk_size"]        != "" ? var.storage["disk_size"]        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${var.storage["eagerly_scrub"]    != "" ? var.storage["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.storage["thin_provisioned"] != "" ? var.storage["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.storage["keep_disk_on_remove"]}"
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-storage-%02d_docker.vmdk", count.index + 1) }"
    size             = "${var.storage["docker_disk_size"]}"
    eagerly_scrub    = "${var.storage["eagerly_scrub"]    != "" ? var.storage["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.storage["thin_provisioned"] != "" ? var.storage["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.storage["keep_disk_on_remove"]}"
    unit_number      = 1
  }

  disk {
    label            = "${format("${lower(var.instance_name)}-storage-%02d_gluster.vmdk", count.index + 1) }"
    size             = "${var.storage["gluster_disk_size"]}"
    eagerly_scrub    = "${var.storage["eagerly_scrub"]    != "" ? var.storage["eagerly_scrub"]    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${var.storage["thin_provisioned"] != "" ? var.storage["thin_provisioned"] : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${var.storage["keep_disk_on_remove"]}"
    unit_number      = 2
  }
  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }


  #####
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${format("${lower(var.instance_name)}-storage-%02d", count.index + 1) }"
        domain    = "${var.domain != "" ? var.domain : format("%s.local", var.instance_name)}"
      }

      network_interface {
        ipv4_address  = "${var.staticipblock != "0.0.0.0/0" ? cidrhost(var.staticipblock, 1 + var.staticipblock_offset + var.bastion["nodes"] + var.master["nodes"] + var.infra["nodes"] + var.worker["nodes"] + count.index) : ""}"
        ipv4_netmask  = "${var.netmask}"
      }

      ipv4_gateway    = "${var.gateway}"
      dns_server_list = "${var.dns_servers}"
    }
  }

  # Specify the ssh connection
  connection {
    user          = "${var.ssh_user}"
    password      = "${var.ssh_password}"
    bastion_host  = "${vsphere_virtual_machine.bastion.default_ip_address}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${local.public_ssh_key}\"",
    ]
  }
}


resource "random_id" "completed" {
    byte_length = 1
    depends_on = [
        "vsphere_virtual_machine.bastion",
        "vsphere_virtual_machine.master",
        "vsphere_virtual_machine.infra",
        "vsphere_virtual_machine.worker",
        "vsphere_virtual_machine.storage",
    ]
}
