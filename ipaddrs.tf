locals {
  node_count = "${lookup(var.bastion, "nodes", "1") + lookup(var.master, "nodes", "1") + lookup(var.infra, "nodes", "1") + lookup(var.worker, "nodes", "3") + lookup(var.storage, "nodes", "3")}"
  gateways = ["${compact(list(var.public_gateway, var.private_gateway))}"]
}

data "template_file" "bastion_private_ips" {
  count = "${lookup(var.bastion, "nodes", "1")}"

  # use master ip address array if it's defined, otherwise select one from private ip list
  template = "${length(var.bastion_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             count.index) : 
    element(var.bastion_ip_address, count.index)}"
}

data "template_file" "master_private_ips" {
  count = "${lookup(var.master, "nodes", "1")}"

  # use master ip address array if it's defined, otherwise select one from private ip list
  template = "${length(var.master_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             lookup(var.bastion, "nodes", "1") + 
             count.index) : 
    element(var.master_ip_address, count.index)}"

}

data "template_file" "infra_private_ips" {
  count = "${lookup(var.infra, "nodes", "1")}"

  template = "${length(var.infra_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             lookup(var.bastion, "nodes", "1") + 
             lookup(var.master, "nodes", "1") + 
             count.index) : 
    element(var.infra_ip_address, count.index)}"

}

data "template_file" "worker_private_ips" {
  count = "${lookup(var.worker, "nodes", "3")}"

  # use worker ip address array if it's defined, otherwise select one from private ip list
  template = "${length(var.worker_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             lookup(var.bastion, "nodes", "1") + 
             lookup(var.master, "nodes", "1") + 
             lookup(var.infra, "nodes", "1") + 
             count.index) : 
    element(var.worker_ip_address, count.index)}"
}

data "template_file" "storage_private_ips" {
  count = "${lookup(var.storage, "nodes", "3")}"

  template = "${length(var.storage_ip_address) == 0 ? 
    cidrhost(var.private_staticipblock, 
             1 + 
             var.private_staticipblock_offset + 
             lookup(var.bastion, "nodes", "1") + 
             lookup(var.master, "nodes", "1") + 
             lookup(var.infra, "nodes", "1") + 
             lookup(var.worker, "nodes", "3") + 
             count.index) : 
    element(var.storage_ip_address, count.index)}"

}

data "template_file" "public_ips" {
  count = "${var.public_network_id != "" ? lookup(var.bastion, "nodes", "1") : 0}"

  template = "${cidrhost(var.public_staticipblock, 1 + var.public_staticipblock_offset + count.index)}"
}
