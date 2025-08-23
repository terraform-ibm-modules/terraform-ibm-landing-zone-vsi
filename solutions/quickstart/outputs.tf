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
  value       = var.auto_generate_ssh_key ? tls_private_key.auto_generate_ssh_key[0].private_key_pem : null
  description = "The ssh private key data in [PEM (RFC 1421)](https://datatracker.ietf.org/doc/html/rfc1421) format."
  sensitive   = true
}
