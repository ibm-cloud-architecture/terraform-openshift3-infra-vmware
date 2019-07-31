# #################################################
# # Output Bastion Node
# #################################################
#
output "bastion_public_ip" {
    value = "${vsphere_virtual_machine.bastion.*.default_ip_address[0]}"
}

output "bastion_hostname" {
    value = "${vsphere_virtual_machine.bastion.*.name[0]}"
}


#################################################
# Output Master Node
#################################################
output "master_private_ip" {
    value = "${vsphere_virtual_machine.master.*.default_ip_address}"
}

output "master_hostname" {
    value = "${vsphere_virtual_machine.master.*.name}"
}


#################################################
# Output Infra Node
#################################################
output "infra_private_ip" {
    value = "${vsphere_virtual_machine.infra.*.default_ip_address}"
}

output "infra_hostname" {
    value = "${vsphere_virtual_machine.infra.*.name}"
}


#################################################
# Output App Node
#################################################
output "app_private_ip" {
    value = "${vsphere_virtual_machine.worker.*.default_ip_address}"
}

output "app_hostname" {
    value = "${vsphere_virtual_machine.worker.*.name}"
}


#################################################
# Output Storage Node
#################################################
output "storage_private_ip" {
    value = "${vsphere_virtual_machine.storage.*.default_ip_address}"
}

output "storage_hostname" {
    value = "${vsphere_virtual_machine.storage.*.name}"
}

#################################################
# Output LBaaS VIP
#################################################
output "haproxy_public_ip" {
    value = "${vsphere_virtual_machine.haproxy.*.default_ip_address}"
}

output "haproxy_hostname" {
    value = "${vsphere_virtual_machine.haproxy.*.name}"
}

output "public_master_vip" {
    value = "ocp-vmware-master.rtp.raleigh.ibm.com"
}

output "public_app_vip" {
    value = "ocp-vmware-apps.rtp.raleigh.ibm.com"
}

#################################################
# Output OpenShift
#################################################
# output "kubeconfig" {
#     value = "${module.kubeconfig.config}"
# }
