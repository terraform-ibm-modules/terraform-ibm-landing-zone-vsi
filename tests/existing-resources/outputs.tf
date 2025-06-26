########################################################################################################################
# Outputs
########################################################################################################################

output "resource_group_id" {
  description = "The id of the resource group where resources are created."
  value       = module.resource_group.resource_group_id
}

output "resource_group_name" {
  description = "The name of the resource group where resources are created."
  value       = module.resource_group.resource_group_name
}

output "vpc_crn" {
  value       = module.vpc.vpc_crn
  description = "VPC CRN."
}

output "subnet_id" {
  value       = module.vpc.subnet_zone_list[0].id
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
  value       = data.ibm_is_image.image.id
  description = "Image ID."
}
