##############################################################################
# Locals
##############################################################################

locals {
  resource_group_id = var.resource_group != null ? data.ibm_resource_group.existing_resource_group[0].id : ibm_resource_group.resource_group[0].id
}

##############################################################################
# Resource Group
# (if var.resource_group is null, create a new RG using var.prefix)
##############################################################################

resource "ibm_resource_group" "resource_group" {
  count    = var.resource_group != null ? 0 : 1
  name     = "${var.prefix}-rg"
  quota_id = null
}

data "ibm_resource_group" "existing_resource_group" {
  count = var.resource_group != null ? 1 : 0
  name  = var.resource_group
}

#############################################################################
# Provision VPC
#############################################################################

module "slz_vpc" {
  # TODO: set the release version once it is ready
  source            = "git::https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vpc.git?ref=init-vpc-mod"
  resource_group_id = local.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  vpc_name          = var.prefix
}

#############################################################################
# Provision VSI
#############################################################################

module "slz_vsi" {
  source            = "../../"
  resource_group_id = local.resource_group_id
  image_id = var.image_id
  create_security_group = false
  security_group = null
  tags = var.resource_tags
  subnets = []
  vpc_id = module.slz_vpc.vpc_id
  prefix = var.prefix
  machine_type = var.machine_type
  user_data = var.user_data
  boot_volume_encryption_key = var.boot_volume_encryption_key
  vsi_per_subnet = var.vsi_per_subnet
  ssh_key_ids = var.ssh_key_ids
}
