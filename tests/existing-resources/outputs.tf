########################################################################################################################
# Outputs
########################################################################################################################

output "resource_group_id" {
  description = "The id of the resource group where resources are created"
  value       = module.resource_group.resource_group_id
}

output "resource_group_name" {
  description = "The name of the resource group where resources are created"
  value       = module.resource_group.resource_group_name
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC id"
}

output "subnet_id" {
  value       = module.vpc.subnet_zone_list[0].id
  description = "A list containing subnet IDs and subnet zones"
}
