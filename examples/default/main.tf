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

##############################################################################
# Create new SSH key
##############################################################################
resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "ibm_is_ssh_key" "ssh_key" {
  name       = var.prefix
  public_key = resource.tls_private_key.tls_key.public_key_openssh
}

#############################################################################
# Provision VPC
#############################################################################

module "slz_vpc" {
  source            = "git::https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vpc.git?ref=v1.0.0"
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
  subnets = module.slz_vpc.subnet_zone_list
  vpc_id = module.slz_vpc.vpc_id
  prefix = var.prefix
  machine_type = var.machine_type
  user_data = var.user_data
  boot_volume_encryption_key = var.boot_volume_encryption_key
  vsi_per_subnet = var.vsi_per_subnet
  ssh_key_ids = [resource.ibm_is_ssh_key.ssh_key.id]
}
