locals {
  node_count = "${var.bastion["nodes"] + var.master["nodes"] + var.infra["nodes"] + var.worker["nodes"] + var.storage["nodes"]}"
  gateways = ["${compact(list(var.public_gateway, var.private_gateway))}"]
}

data "template_file" "bastion_private_ips" {
  count = "${var.bastion["nodes"]}"

  # use master ip address array if it's defined, otherwise select one from private ip list
  template = "${length(var.bastion_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             count.index) : 
    element(var.bastion_ip_address, count.index)}"
}

data "template_file" "master_private_ips" {
  count = "${var.master["nodes"]}"

  # use master ip address array if it's defined, otherwise select one from private ip list
  template = "${length(var.master_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             var.bastion["nodes"] + 
             count.index) : 
    element(var.master_ip_address, count.index)}"

}

data "template_file" "infra_private_ips" {
  count = "${var.infra["nodes"]}"

  template = "${length(var.infra_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             var.bastion["nodes"] + 
             var.master["nodes"] + 
             count.index) : 
    element(var.infra_ip_address, count.index)}"

}

data "template_file" "worker_private_ips" {
  count = "${var.worker["nodes"]}"

  # use worker ip address array if it's defined, otherwise select one from private ip list
  template = "${length(var.worker_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             var.bastion["nodes"] + 
             var.master["nodes"] + 
             var.infra["nodes"] + 
             count.index) : 
    element(var.worker_ip_address, count.index)}"
}

data "template_file" "storage_private_ips" {
  count = "${var.storage["nodes"]}"

  template = "${length(var.storage_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             var.bastion["nodes"] + 
             var.master["nodes"] + 
             var.infra["nodes"] + 
             var.worker["nodes"] + 
             count.index) : 
    element(var.storage_ip_address, count.index)}"

}

data "template_file" "public_ips" {
  count = "${var.public_network_id != "" ? var.bastion["nodes"] : 0}"

  template = "${cidrhost(var.public_staticipblock, 1 + var.public_staticipblock_offset + count.index)}"
}
