##############################################################################
# VSI Outputs
##############################################################################

output "ids" {
  description = "The IDs of the VSIs."
  value       = module.vsi.ids
}

output "vsi_security_group" {
  description = "Security group for the VSI."
  value       = module.vsi.vsi_security_group
}

output "vsi_data" {
  description = "A list of VSI with name, id, zone, and primary ipv4 address."
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

output "load_balancers_metadata" {
  description = "Load balancers metadata."
  value       = length(module.vsi.load_balancers_metadata) > 0 ? module.vsi.load_balancers_metadata : null
}

output "lb_security_groups" {
  description = "Load Balancer security groups."
  value       = module.vsi.lb_security_groups
}

##############################################################################

##############################################################################
# Consistency Group Outputs
##############################################################################

output "consistency_group_boot_snapshot_id" {
  description = "The Snapshot Id used for the VSI boot volume, determined from an optionally supplied consistency group."
  value       = module.vsi.consistency_group_boot_snapshot_id
}

output "consistency_group_storage_snapshot_ids" {
  description = "Map of attached storage volumes requested, and the Snapshot Ids that will be used, determined from an optionally supplied consistency group, and mapped. "
  value       = module.vsi.consistency_group_storage_snapshot_ids
}

##############################################################################

##############################################################################
# Trusted Profile Outputs
##############################################################################

output "logging_trusted_profile_id" {
  description = "The ID of the trusted profile used for logging agent authentication. Returns null if not using trusted profile authentication or if using an existing profile."
  value       = local.create_logging_trusted_profile ? ibm_iam_trusted_profile.logging_profile[0].id : null
}

output "logging_trusted_profile_name" {
  description = "The name of the trusted profile used for logging agent authentication. Returns null if not using trusted profile authentication or if using an existing profile."
  value       = local.create_logging_trusted_profile ? ibm_iam_trusted_profile.logging_profile[0].name : null
}

##############################################################################

##############################################################################
# SSH Key
##############################################################################

output "ssh_private_key" {
  value       = var.auto_generate_ssh_key ? tls_private_key.auto_generate_ssh_key[0].private_key_pem : null
  description = "The ssh private key data in [PEM (RFC 1421)](https://datatracker.ietf.org/doc/html/rfc1421) format."
  sensitive   = true
}

output "next_steps_text" {
  value       = "Your Virtual Server Instance is ready."
  description = "Next steps text"
}

output "next_step_primary_label" {
  value       = "Go to Virtual Server Instance"
  description = "Primary label"
}

output "next_step_primary_url" {
  value       = "https://cloud.ibm.com/infrastructure/compute/vs/${module.existing_vpc_crn_parser.region}~${module.vsi.ids[0]}/overview"
  description = "Primary URL"
}

output "next_step_secondary_label" {
  value       = "SSH Connection Guide"
  description = "Secondary label"
}

output "next_step_secondary_url" {
  value       = "https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/blob/main/solutions/quickstart/ssh_connection_guide.md"
  description = "Secondary URL"
}
