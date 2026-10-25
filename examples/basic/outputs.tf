output "slz_vpc" {
  value       = module.slz_vpc
  description = "VPC module values"
}

output "slz_vsi" {
  value       = module.slz_vsi
  description = "VSI module values"
}

output "image_id" {
  value       = module.vsi_image_selector.latest_image_id
  description = "The image ID used for the VSI"
}
