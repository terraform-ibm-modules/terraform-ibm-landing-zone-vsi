##############################################################################
# Locals
##############################################################################

locals {
  resource_group_id = var.resource_group != null ? data.ibm_resource_group.existing_resource_group[0].id : ibm_resource_group.resource_group[0].id
  ssh_key_id        = var.ssh_key != null ? data.ibm_is_ssh_key.existing_ssh_key[0].id : ibm_is_ssh_key.ssh_key[0].id
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
# SSH key
##############################################################################
resource "tls_private_key" "tls_key" {
  count     = var.ssh_key != null ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "ibm_is_ssh_key" "ssh_key" {
  count      = var.ssh_key != null ? 0 : 1
  name       = "${var.prefix}-ssh-key"
  public_key = tls_private_key.tls_key[0].public_key_openssh
}

data "ibm_is_ssh_key" "existing_ssh_key" {
  count = var.ssh_key != null ? 1 : 0
  name  = var.ssh_key
}

#############################################################################
# Provision VPC
#############################################################################

module "slz_vpc" {
  source            = "git::https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vpc.git?ref=v7.2.0"
  resource_group_id = local.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  name              = var.vpc_name
}

#############################################################################
# Provision VSI
#############################################################################

module "slz_vsi" {
  source                     = "../../profiles/fscloud"
  resource_group_id          = local.resource_group_id
  image_id                   = var.image_id
  create_security_group      = var.create_security_group
  security_group             = var.security_group
  tags                       = var.resource_tags
  subnets                    = module.slz_vpc.subnet_zone_list
  vpc_id                     = module.slz_vpc.vpc_id
  prefix                     = var.prefix
  machine_type               = var.machine_type
  user_data                  = var.user_data
  boot_volume_encryption_key = var.boot_volume_encryption_key
  existing_kms_instance_guid = var.existing_kms_instance_guid
  vsi_per_subnet             = var.vsi_per_subnet
  ssh_key_ids                = [local.ssh_key_id]
}
