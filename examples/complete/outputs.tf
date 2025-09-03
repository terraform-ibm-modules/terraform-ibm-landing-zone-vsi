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

output "load_balancers_metadata" {
  description = "Load Balancers metadata."
  value       = module.slz_vsi.load_balancers_metadata
}

output "lb_security_groups" {
  description = "Load Balancer security groups"
  value       = module.slz_vsi.lb_security_groups
}
