##############################################################################
# SLZ VPC
##############################################################################

module "landing_zone" {
  source           = "terraform-ibm-modules/landing-zone/ibm//patterns//vpc//module"
  version          = "4.9.0"
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  prefix           = var.prefix
  tags             = var.resource_tags
}
