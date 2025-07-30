output "slz_vpc" {
  value       = module.slz_vpc
  description = "VPC module values"
}

output "slz_vsi" {
  value       = module.slz_vsi.list
  description = "VSI module values"
}
