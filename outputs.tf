# #################################################
# # Output Bastion Node
# #################################################
#
output "bastion_public_ip" {
  value = "${element(compact(concat(vsphere_virtual_machine.bastion.*.default_ip_address, vsphere_virtual_machine.bastion_ds_cluster.*.default_ip_address)), 0)}"
}

# always the first private IP
output "bastion_private_ip" {
  value = "${element(data.template_file.private_ips.*.rendered, 0)}"
}

output "bastion_hostname" {
  value = "${element(compact(concat(vsphere_virtual_machine.bastion.*.name, vsphere_virtual_machine.bastion_ds_cluster.*.name)), 0)}"
}


#################################################
# Output Master Node
#################################################
output "master_private_ip" {
  value = "${compact(concat(vsphere_virtual_machine.master.*.default_ip_address, vsphere_virtual_machine.master_ds_cluster.*.default_ip_address))}"
}

output "master_hostname" {
  value = "${compact(concat(vsphere_virtual_machine.master.*.name, vsphere_virtual_machine.master_ds_cluster.*.name))}"
}


#################################################
# Output Infra Node
#################################################
output "infra_private_ip" {
  value = "${compact(concat(vsphere_virtual_machine.infra.*.default_ip_address, vsphere_virtual_machine.infra_ds_cluster.*.default_ip_address))}"
}

output "infra_hostname" {
  value = "${compact(concat(vsphere_virtual_machine.infra.*.name, vsphere_virtual_machine.infra_ds_cluster.*.name))}"
}


#################################################
# Output App Node
#################################################
output "worker_private_ip" {
  value = "${compact(concat(vsphere_virtual_machine.worker.*.default_ip_address, vsphere_virtual_machine.worker_ds_cluster.*.default_ip_address))}"
}

output "worker_hostname" {
  value = "${compact(concat(vsphere_virtual_machine.worker.*.name, vsphere_virtual_machine.worker_ds_cluster.*.name))}"
}


#################################################
# Output Storage Node
#################################################
output "storage_private_ip" {
  value = "${compact(concat(vsphere_virtual_machine.storage.*.default_ip_address, vsphere_virtual_machine.storage_ds_cluster.*.default_ip_address))}"
}

output "storage_hostname" {
  value = "${compact(concat(vsphere_virtual_machine.storage.*.name, vsphere_virtual_machine.storage_ds_cluster.*.name))}"
}

