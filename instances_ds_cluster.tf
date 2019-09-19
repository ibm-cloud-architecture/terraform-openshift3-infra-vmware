#################################
# Configure the VMware vSphere Provider
##################################
##################################
#### Create the Bastion VM
##################################
resource "vsphere_virtual_machine" "bastion_ds_cluster" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${var.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.datastore_cluster_id != "" ? lookup(var.bastion, "nodes", "1") : 0}"
  resource_pool_id = "${var.vsphere_resource_pool_id}"

  name      = "${format("${lower(var.instance_name)}-bastion-%02d", count.index + 1) }"
  num_cpus  = "${lookup(var.bastion, "vcpu", "2")}"
  memory    = "${lookup(var.bastion, "memory", "4096")}"

  scsi_controller_count = 1

  ####
  # Disk specifications
  ####
  datastore_cluster_id  = "${var.datastore_cluster_id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"

  disk {
    label            = "disk0"
    size             = "${lookup(var.bastion, "disk_size", "")        != "" ? lookup(var.bastion, "disk_size", "")        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${lookup(var.bastion, "eagerly_scrub", "")    != "" ? lookup(var.bastion, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.bastion, "thin_provisioned", "") != "" ? lookup(var.bastion, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.bastion, "keep_disk_on_remove", "false")}"
    unit_number      = 0
  }

  disk {
    label            = "disk1"
    size             = "${lookup(var.bastion, "docker_disk_size", "100")}"
    eagerly_scrub    = "${lookup(var.bastion, "eagerly_scrub", "")    != "" ? lookup(var.bastion, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.bastion, "thin_provisioned", "") != "" ? lookup(var.bastion, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.bastion, "keep_disk_on_remove", "false")}"
    unit_number      = 1
  }

  ####
  # Network specifications
  ####
  dynamic "network_interface" {
    for_each = compact(concat(list(var.public_network_id, var.private_network_id)))
    content {
      network_id   = "${network_interface.value}"
      adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
    }
  }

  ####
  # VM Customizations
  ####
  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${var.instance_name}-bastion"
        domain    = "${var.private_domain != "" ? var.private_domain : format("%s.local", var.instance_name)}"
      }

      dynamic "network_interface" {
        for_each = compact(concat(list(var.public_network_id, var.private_network_id)))
        content {
          ipv4_address = "${element(concat(data.template_file.public_ips.*.rendered, data.template_file.bastion_private_ips.*.rendered), network_interface.key)}"
          ipv4_netmask = "${element(compact(concat(list(var.public_netmask), list(var.private_netmask))), network_interface.key)}"
        }
      }

      ipv4_gateway    = "${var.public_gateway != "" ? var.public_gateway : var.private_gateway}"
      dns_server_list = compact(concat(var.private_dns_servers, var.public_dns_servers))
      dns_suffix_list = compact(list(var.private_domain, var.public_domain))

    }
  }
  
  # Specify the ssh connection
  connection {
    host          = "${self.default_ip_address}"
    user          = "${var.template_ssh_user}"
    password      = "${var.template_ssh_password}"
    private_key   = "${var.template_ssh_private_key}"
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-private-ssh-key.sh \"${var.ssh_private_key}\" \"${var.ssh_user}\"",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${var.ssh_public_key}\""
    ]
  }
}

##################################
#### Create the Master VM
##################################
resource "vsphere_virtual_machine" "master_ds_cluster" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${var.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.datastore_cluster_id != "" ? lookup(var.master, "nodes", "1") : 0}"
  resource_pool_id = "${var.vsphere_resource_pool_id}"

  name      = "${format("${lower(var.instance_name)}-master-%02d", count.index + 1) }"
  num_cpus  = "${lookup(var.master, "vcpu", "8")}"
  memory    = "${lookup(var.master, "memory", "32768")}"

  scsi_controller_count = 1

  ####
  # Disk specifications
  ####
  datastore_cluster_id  = "${var.datastore_cluster_id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"
  enable_disk_uuid = true

  disk {
    label            = "disk0"
    size             = "${lookup(var.master, "disk_size", "")        != "" ? lookup(var.master, "disk_size", "")        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${lookup(var.master, "eagerly_scrub", "")    != "" ? lookup(var.master, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.master, "thin_provisioned", "") != "" ? lookup(var.master, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.master, "keep_disk_on_remove", "false")}"
    unit_number      = 0
  }

  disk {
    label            = "disk1"
    size             = "${lookup(var.master, "docker_disk_size", "100")}"
    eagerly_scrub    = "${lookup(var.master, "eagerly_scrub", "")    != "" ? lookup(var.master, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.master, "thin_provisioned", "") != "" ? lookup(var.master, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.master, "keep_disk_on_remove", "false")}"
    unit_number      = 1
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${var.private_network_id}"
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
        domain    = "${var.private_domain != "" ? var.private_domain : format("%s.local", var.instance_name)}"
      }
      
      network_interface {
        ipv4_address  = "${element(data.template_file.master_private_ips.*.rendered, count.index)}"
        ipv4_netmask  = "${var.private_netmask}"
      }

      ipv4_gateway    = "${var.private_gateway}"
      dns_server_list = "${var.private_dns_servers}"
      dns_suffix_list = ["${var.private_domain}"]
    }
  }

  # Specify the ssh connection
  connection {
    host          = "${self.default_ip_address}"
    user          = "${var.template_ssh_user}"
    password      = "${var.template_ssh_password}"
    private_key   = "${var.template_ssh_private_key}"

    bastion_host          = "${vsphere_virtual_machine.bastion_ds_cluster.0.default_ip_address}"
    bastion_user          = "${var.template_ssh_user}"
    bastion_password      = "${var.template_ssh_password}"
    bastion_private_key   = "${var.template_ssh_private_key}"
   
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${var.ssh_public_key}\""
    ]
  }
 
}

##################################
### Create the Infra VM
##################################
resource "vsphere_virtual_machine" "infra_ds_cluster" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${var.folder_path}"

  lifecycle {
    ignore_changes = [
      "disk"
    ]
  }

  #####
  # VM Specifications
  ####
  count            = "${var.datastore_cluster_id != "" ? lookup(var.infra, "nodes", "1") : 0}"
  resource_pool_id = "${var.vsphere_resource_pool_id}"

  name     = "${format("${lower(var.instance_name)}-infra-%02d", count.index + 1) }"
  num_cpus = "${lookup(var.infra, "vcpu", "8")}"
  memory   = "${lookup(var.infra, "memory", "32768")}"


  ####
  # Disk specifications
  ####
  datastore_cluster_id  = "${var.datastore_cluster_id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"
  enable_disk_uuid = true

  disk {
    label            = "disk0"
    size             = "${lookup(var.infra, "disk_size", "")        != "" ? lookup(var.infra, "disk_size", "")        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${lookup(var.infra, "eagerly_scrub", "")    != "" ? lookup(var.infra, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.infra, "thin_provisioned", "") != "" ? lookup(var.infra, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.infra, "keep_disk_on_remove", "false")}"
    unit_number      = 0
  }

  disk {
    label            = "disk1"
    size             = "${lookup(var.infra, "docker_disk_size", "100")}"
    eagerly_scrub    = "${lookup(var.infra, "eagerly_scrub", "")    != "" ? lookup(var.infra, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.infra, "thin_provisioned", "") != "" ? lookup(var.infra, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.infra, "keep_disk_on_remove", "false")}"
    unit_number      = 1
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${var.private_network_id}"
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
        domain    = "${var.private_domain != "" ? var.private_domain : format("%s.local", var.instance_name)}"
      }

      network_interface {
        ipv4_address  = "${element(data.template_file.infra_private_ips.*.rendered, count.index)}"
        ipv4_netmask  = "${var.private_netmask}"
      }

      ipv4_gateway    = "${var.private_gateway}"
      dns_server_list = "${var.private_dns_servers}"
      dns_suffix_list = ["${var.private_domain}"]
    }
  }
 
  # Specify the ssh connection
  connection {
    host          = "${self.default_ip_address}"
    user          = "${var.template_ssh_user}"
    password      = "${var.template_ssh_password}"
    private_key   = "${var.template_ssh_private_key}"

    bastion_host          = "${vsphere_virtual_machine.bastion_ds_cluster.0.default_ip_address}"
    bastion_user          = "${var.template_ssh_user}"
    bastion_password      = "${var.template_ssh_password}"
    bastion_private_key   = "${var.template_ssh_private_key}"

  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${var.ssh_public_key}\""
    ]
  }
 
}

##################################
### Create the Worker VM
##################################
resource "vsphere_virtual_machine" "worker_ds_cluster" {
  #depends_on = ["vsphere_folder.ocpenv"]
  lifecycle {
    ignore_changes = [
      "disk"
    ]
  }

  folder     = "${var.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.datastore_cluster_id != "" ? lookup(var.worker, "nodes", "3") : 0}"
  resource_pool_id = "${var.vsphere_resource_pool_id}"

  name     = "${format("${lower(var.instance_name)}-worker-%02d", count.index + 1) }"
  num_cpus = "${lookup(var.worker, "vcpu", "4")}"
  memory   = "${lookup(var.worker, "memory", "16384")}"


  #####
  # Disk Specifications
  ####
  datastore_cluster_id  = "${var.datastore_cluster_id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"
  enable_disk_uuid = true

  disk {
    label            = "disk0"
    size             = "${lookup(var.worker, "disk_size", "")        != "" ? lookup(var.worker, "disk_size", "")        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${lookup(var.worker, "eagerly_scrub", "")    != "" ? lookup(var.worker, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.worker, "thin_provisioned", "") != "" ? lookup(var.worker, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.worker, "keep_disk_on_remove", "false")}"
    unit_number      = 0
  }

  disk {
    label            = "disk1"
    size             = "${lookup(var.worker, "docker_disk_size", "100")}"
    eagerly_scrub    = "${lookup(var.worker, "eagerly_scrub", "")    != "" ? lookup(var.worker, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.worker, "thin_provisioned", "") != "" ? lookup(var.worker, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.worker, "keep_disk_on_remove", "false")}"
    unit_number      = 1
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${var.private_network_id}"
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
        domain    = "${var.private_domain != "" ? var.private_domain : format("%s.local", var.instance_name)}"
      }

      network_interface {
        ipv4_address  = "${element(data.template_file.worker_private_ips.*.rendered, count.index)}"
        ipv4_netmask  = "${var.private_netmask}"
      }

      ipv4_gateway    = "${var.private_gateway}"
      dns_server_list = "${var.private_dns_servers}"
      dns_suffix_list = ["${var.private_domain}"]
    }
  }

  # Specify the ssh connection
  connection {
    host          = "${self.default_ip_address}"
    user          = "${var.template_ssh_user}"
    password      = "${var.template_ssh_password}"
    private_key   = "${var.template_ssh_private_key}"
 
    bastion_host          = "${vsphere_virtual_machine.bastion_ds_cluster.0.default_ip_address}"
    bastion_user          = "${var.template_ssh_user}"
    bastion_password      = "${var.template_ssh_password}"
    bastion_private_key   = "${var.template_ssh_private_key}"
   
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${var.ssh_public_key}\""
    ]
  }
 
}

##################################
### Create the Storage VM
##################################
resource "vsphere_virtual_machine" "storage_ds_cluster" {
  #depends_on = ["vsphere_folder.ocpenv"]
  folder     = "${var.folder_path}"

  #####
  # VM Specifications
  ####
  count            = "${var.datastore_cluster_id != "" ? lookup(var.storage, "nodes", "3") : 0}"
  resource_pool_id = "${var.vsphere_resource_pool_id}"

  name     = "${format("${lower(var.instance_name)}-storage-%02d", count.index + 1) }"
  num_cpus = "${lookup(var.storage, "vcpu", "8")}"
  memory   = "${lookup(var.storage, "memory", "16384")}"


  #####
  # Disk Specifications
  ####
  datastore_cluster_id  = "${var.datastore_cluster_id}"
  guest_id      = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type     = "${data.vsphere_virtual_machine.template.scsi_type}"
  enable_disk_uuid = true

  disk {
    label            = "disk0"
    size             = "${lookup(var.storage, "disk_size", "")        != "" ? lookup(var.storage, "disk_size", "")        : data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${lookup(var.storage, "eagerly_scrub", "")    != "" ? lookup(var.storage, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.storage, "thin_provisioned", "") != "" ? lookup(var.storage, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.storage, "keep_disk_on_remove", "false")}"
    unit_number      = 0
  }

  disk {
    label            = "disk1"
    size             = "${lookup(var.storage, "docker_disk_size", "100")}"
    eagerly_scrub    = "${lookup(var.storage, "eagerly_scrub", "")    != "" ? lookup(var.storage, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${lookup(var.storage, "thin_provisioned", "") != "" ? lookup(var.storage, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
    keep_on_remove   = "${lookup(var.storage, "keep_disk_on_remove", "false")}"
    unit_number      = 1
  }

  dynamic "disk" {
    for_each = [for disk_num in range(lookup(var.storage, "gluster_num_disks", "1")): disk_num + 2]
    content {
      label            = "${format("disk%d", disk.value)}"
      size             = "${lookup(var.storage, "gluster_disk_size", "250")}"
      eagerly_scrub    = "${lookup(var.storage, "eagerly_scrub", "")    != "" ? lookup(var.storage, "eagerly_scrub", "")    : data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
      thin_provisioned = "${lookup(var.storage, "thin_provisioned", "") != "" ? lookup(var.storage, "thin_provisioned", "") : data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
      keep_on_remove   = "${lookup(var.storage, "keep_disk_on_remove", "false")}"
      unit_number      = disk.value
    }
  }

  ####
  # Network specifications
  ####
  network_interface {
    network_id   = "${var.private_network_id}"
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
        domain    = "${var.private_domain != "" ? var.private_domain : format("%s.local", var.instance_name)}"
      }

      network_interface {
        ipv4_address  = "${element(data.template_file.storage_private_ips.*.rendered, count.index)}"
        ipv4_netmask  = "${var.private_netmask}"
      }

      ipv4_gateway    = "${var.private_gateway}"
      dns_server_list = "${var.private_dns_servers}"
      dns_suffix_list = ["${var.private_domain}"]
    }
  }

  # Specify the ssh connection
  connection {
    host          = "${self.default_ip_address}"
    user          = "${var.template_ssh_user}"
    password      = "${var.template_ssh_password}"
    private_key   = "${var.template_ssh_private_key}"

    bastion_host          = "${vsphere_virtual_machine.bastion_ds_cluster.0.default_ip_address}"
    bastion_user          = "${var.template_ssh_user}"
    bastion_password      = "${var.template_ssh_password}"
    bastion_private_key   = "${var.template_ssh_private_key}"
   
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/terraform_scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod u+x /tmp/terraform_scripts/*.sh",
      "/tmp/terraform_scripts/add-public-ssh-key.sh \"${var.ssh_public_key}\""
    ]
  }
 
}



