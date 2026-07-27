output "slz_vsi" {
  value       = module.fscloud_vsi
  description = "VSI module values"
}

output "slz_primary_vni" {
  value       = module.fscloud_vsi.primary_vni_details
  description = "Primary VNI details"
}

output "slz_secondary_vni" {
  value       = module.fscloud_vsi.secondary_vni_details
  description = "Secondary VNI details"
}
