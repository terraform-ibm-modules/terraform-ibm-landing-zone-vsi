##############################################################################
# VSI Outputs
##############################################################################

output "ids" {
  description = "The IDs of the VSIs"
  value       = module.vsi.ids
}

output "vsi_security_group" {
  description = "Security group for the VSI"
  value       = module.vsi.vsi_security_group
}

output "vsi_data" {
  description = "A list of VSI with name, id, zone, and primary ipv4 address"
  value       = module.vsi.list
}

output "fip_list" {
  description = "A list of VSI with name, id, zone, and primary ipv4 address, and floating IP. This list only contains instances with a floating IP attached."
  value       = length(module.vsi.fip_list) > 0 ? module.vsi.fip_list : null
}

##############################################################################

##############################################################################
# Load Balancer Outputs
##############################################################################

output "lb_hostnames" {
  description = "Hostnames for the Load Balancer created"
  value       = length(module.vsi.lb_hostnames) > 0 ? module.vsi.lb_hostnames : null
}

output "lb_security_groups" {
  description = "Load Balancer security groups"
  value       = module.vsi.lb_security_groups
}

##############################################################################

##############################################################################
# Consistency Group Outputs
##############################################################################

output "consistency_group_boot_snapshot_id" {
  description = "The Snapshot Id used for the VSI boot volume, determined from an optionally supplied consistency group"
  value       = module.vsi.consistency_group_boot_snapshot_id
}

output "consistency_group_storage_snapshot_ids" {
  description = "Map of attached storage volumes requested, and the Snapshot Ids that will be used, determined from an optionally supplied consistency group, and mapped "
  value       = module.vsi.consistency_group_storage_snapshot_ids
}

##############################################################################
