##############################################################################
# Outputs
##############################################################################

output "prefix" {
  value       = module.landing_zone.prefix
  description = "prefix"
}

output "vpc_data" {
  value = module.landing_zone.vpc_data
}
