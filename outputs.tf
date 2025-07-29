##############################################################################
# VSI Outputs
##############################################################################

output "ids" {
  description = "The IDs of the VSI"
  value = [
    for virtual_server in ibm_is_instance.vsi :
    virtual_server.id
  ]
}

output "vsi_security_group" {
  description = "Security group for the VSI"
  value       = var.security_group != null && var.create_security_group == true ? ibm_is_security_group.security_group[var.security_group.name] : null
}

output "list" {
  description = "A list of VSI with name, id, zone, and primary ipv4 address"
  value = [
    for vsi_key, virtual_server in ibm_is_instance.vsi :
    {
      name                   = virtual_server.name
      id                     = virtual_server.id
      zone                   = virtual_server.zone
      ipv4_address           = virtual_server.primary_network_interface[0].primary_ipv4_address
      secondary_ipv4_address = length(virtual_server.network_interfaces) == 0 ? null : virtual_server.network_interfaces[0].primary_ipv4_address
      floating_ip            = var.enable_floating_ip ? ibm_is_floating_ip.vsi_fip[vsi_key].address : null
      floating_ip_id         = var.enable_floating_ip ? ibm_is_floating_ip.vsi_fip[vsi_key].id : null
      floating_ip_crn        = var.enable_floating_ip ? ibm_is_floating_ip.vsi_fip[vsi_key].crn : null
      vpc_id                 = var.vpc_id
      snapshot_id            = one(virtual_server.boot_volume[*].snapshot)
    }
  ]
}

output "vsi_full_detail_map" {
  description = "A list of all deployed VSI with their full detail map, organized by VSI name"
  value       = { for vsi_key, virtual_server in ibm_is_instance.vsi : virtual_server.name => virtual_server }
}

output "fip_list" {
  description = "A list of VSI with name, id, zone, and primary ipv4 address, and floating IP. This list only contains instances with a floating IP attached."
  value = [
    for vsi_key, virtual_server in ibm_is_instance.vsi :
    {
      name                   = virtual_server.name
      id                     = virtual_server.id
      zone                   = virtual_server.zone
      ipv4_address           = virtual_server.primary_network_interface[0].primary_ipv4_address
      secondary_ipv4_address = length(virtual_server.network_interfaces) == 0 ? null : virtual_server.network_interfaces[0].primary_ipv4_address
      floating_ip            = var.enable_floating_ip ? ibm_is_floating_ip.vsi_fip[vsi_key].address : null
      floating_ip_id         = var.enable_floating_ip ? ibm_is_floating_ip.vsi_fip[vsi_key].id : null
      floating_ip_crn        = var.enable_floating_ip ? ibm_is_floating_ip.vsi_fip[vsi_key].crn : null
      vpc_id                 = var.vpc_id
    } if var.enable_floating_ip == true
  ]
}

##############################################################################

##############################################################################
# Load Balancer Outputs
##############################################################################

output "lb_hostnames" {
  description = "Hostnames for the Load Balancer created"
  value = [
    for load_balancer in ibm_is_lb.lb :
    load_balancer.hostname
  ]
}

output "lb_security_groups" {
  description = "Load Balancer security groups"
  value = {
    for load_balancer in var.load_balancers :
    (load_balancer.name) => ibm_is_security_group.security_group[load_balancer.security_group.name] if load_balancer.security_group != null
  }
}

##############################################################################

##############################################################################
# Consistency Group Outputs
##############################################################################

output "consistency_group_boot_snapshot_id" {
  description = "The Snapshot Id used for the VSI boot volume, determined from an optionally supplied consistency group"
  value       = local.consistency_group_boot_snapshot_id
}

output "consistency_group_storage_snapshot_ids" {
  description = "Map of attached storage volumes requested, and the Snapshot Ids that will be used, determined from an optionally supplied consistency group, and mapped "
  value       = local.consistency_group_snapshot_to_volume_map
}

##############################################################################
