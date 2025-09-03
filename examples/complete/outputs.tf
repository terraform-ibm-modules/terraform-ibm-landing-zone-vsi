output "slz_vpc" {
  value       = module.slz_vpc
  description = "VPC module values"
}

output "slz_vsi" {
  value       = module.slz_vsi
  description = "VSI module values"
}

output "slz_vsi_dh" {
  value       = module.slz_vsi_dh
  description = "VSI module values"
}

output "secondary_subnets" {
  description = "Secondary subnets created"
  value       = local.secondary_subnet_zone_list
}

output "secondary_security_groups" {
  description = "Secondary security groups created"
  value       = local.secondary_security_groups
}

output "lb_hostnames" {
  description = "Hostnames for the Load Balancer created"
  value       = module.slz_vsi.lb_hostnames
}

output "lb_public_ips" {
  description = "Public IPs for the Load Balancer created"
  value       = module.slz_vsi.lb_public_ips
}

output "lb_private_ips" {
  description = "Private IPs for the Load Balancer created"
  value       = module.slz_vsi.lb_private_ips
}

output "lb_security_groups" {
  description = "Load Balancer security groups"
  value       = module.slz_vsi.lb_security_groups
}
