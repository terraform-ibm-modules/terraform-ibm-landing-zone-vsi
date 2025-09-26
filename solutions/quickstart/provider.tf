########################################################################################################################
# Provider config
########################################################################################################################

provider "ibm" {
  ibmcloud_api_key      = var.ibmcloud_api_key
  region                = local.vpc_region
  visibility            = var.provider_visibility
  private_endpoint_type = (var.provider_visibility == "private" && local.vpc_region == "ca-mon") ? "vpe" : null
}
