########################################################################################################################
# Outputs
########################################################################################################################

output "resource_group_id" {
  description = "The id of the resource group where resources are created."
  value       = var.create_vpc ? module.resource_group[0].resource_group_id : null
}

output "resource_group_name" {
  description = "The name of the resource group where resources are created."
  value       = var.create_vpc ? module.resource_group[0].resource_group_name : null
}

output "vpc_crn" {
  value       = var.create_vpc ? module.vpc[0].vpc_crn : null
  description = "VPC CRN."
}

output "subnet_id" {
  value       = var.create_vpc ? module.vpc[0].subnet_zone_list[0].id : null
  description = "A list containing subnet IDs and subnet zones."
}

output "prefix" {
  description = "Prefix to append to all resources created by this example."
  value       = var.prefix
}

output "region" {
  value       = var.region
  description = "region."
}

output "image_id" {
  value       = module.vsi_image_selector.latest_image_id
  description = "Image ID."
}
