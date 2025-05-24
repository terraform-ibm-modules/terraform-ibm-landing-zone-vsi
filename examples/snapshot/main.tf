##############################################################################
# Locals
##############################################################################

locals {
  ssh_key_id = var.ssh_key != null ? data.ibm_is_ssh_key.existing_ssh_key[0].id : resource.ibm_is_ssh_key.ssh_key[0].id
}

##############################################################################
# Resource Group
##############################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.2.0"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Create new SSH key
##############################################################################

resource "tls_private_key" "tls_key" {
  count     = var.ssh_key != null ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "ibm_is_ssh_key" "ssh_key" {
  count      = var.ssh_key != null ? 0 : 1
  name       = "${var.prefix}-ssh-key"
  public_key = resource.tls_private_key.tls_key[0].public_key_openssh
}

data "ibm_is_ssh_key" "existing_ssh_key" {
  count = var.ssh_key != null ? 1 : 0
  name  = var.ssh_key
}

#############################################################################
# Provision VPC
#############################################################################

module "slz_vpc" {
  source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version           = "7.23.11"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  name              = "vpc"
}

#############################################################################
# Provision VSI
#############################################################################

module "slz_vsi" {
  source                      = "../../"
  resource_group_id           = module.resource_group.resource_group_id
  image_id                    = var.image_id
  create_security_group       = false
  tags                        = var.resource_tags
  access_tags                 = var.access_tags
  subnets                     = module.slz_vpc.subnet_zone_list
  vpc_id                      = module.slz_vpc.vpc_id
  prefix                      = var.prefix
  machine_type                = var.machine_type
  vsi_per_subnet              = 1
  ssh_key_ids                 = [local.ssh_key_id]
  user_data                   = null
  manage_reserved_ips         = true
  enable_floating_ip          = true
  use_static_boot_volume_name = true
  block_storage_volumes = [
    {
      name    = "vsi-block-1"
      profile = "general-purpose"
      # snapshot_id = <you can also specify a specific snapshot ID if requried>
    },
    {
      name    = "vsi-block-2"
      profile = "general-purpose"
      # snapshot_id = <you can also specify a specific snapshot ID if requried>
  }]
  # if specifying a group ID, snapshot IDs will be automatically determined from group using system labels
  snapshot_consistency_group_id = var.snapshot_consistency_group_id
  # boot_volume_snapshot_id = <you can also specify a specific snapshot ID if requried>
}
