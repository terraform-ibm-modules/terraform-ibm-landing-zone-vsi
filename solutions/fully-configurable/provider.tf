########################################################################################################################
# Provider config
########################################################################################################################

provider "ibm" {
  ibmcloud_api_key      = var.ibmcloud_api_key
  region                = local.vpc_region
  visibility            = var.provider_visibility
  private_endpoint_type = (var.provider_visibility == "private" && local.vpc_region == "ca-mon") ? "vpe" : null
}

provider "ibm" {
  alias                 = "kms"
  ibmcloud_api_key      = var.ibmcloud_kms_api_key != null ? var.ibmcloud_kms_api_key : var.ibmcloud_api_key
  region                = local.kms_region
  visibility            = var.provider_visibility
  private_endpoint_type = (var.provider_visibility == "private" && local.kms_region == "ca-mon") ? "vpe" : null
}
