# ##############################################################################
# # VSI Outputs
# ##############################################################################

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
# SSH Key
##############################################################################

output "ssh_private_key" {
  value       = var.existing_ssh_key_name == null ? tls_private_key.tls_key[0].private_key_pem : null
  description = "The ssh private key data in [PEM (RFC 1421)](https://datatracker.ietf.org/doc/html/rfc1421) format."
  sensitive   = true
}

output "next_steps_text" {
  value       = "Now, you can go to the created Virtual Server Instance."
  description = "Next steps text"
}

output "next_step_primary_label" {
  value       = "Go to Virtual Server Instance"
  description = "Primary label"
}

output "next_step_primary_url" {
  value       = length(module.vsi.ids) > 0 ? "https://cloud.ibm.com/infrastructure/compute/vs/${var.existing_vpc_crn != null ? module.existing_vpc_crn_parser[0].region : var.vpc_region}~${module.vsi.ids[0]}/overview" : null
  description = "Primary URL"
}
