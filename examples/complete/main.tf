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
  version = "1.0.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Key Protect All Inclusive
##############################################################################

module "key_protect_all_inclusive" {
  source                    = "terraform-ibm-modules/key-protect-all-inclusive/ibm"
  version                   = "4.2.0"
  resource_group_id         = module.resource_group.resource_group_id
  region                    = var.region
  key_protect_instance_name = "${var.prefix}-kp"
  resource_tags             = var.resource_tags
  key_map                   = { "slz-vsi" = ["${var.prefix}-vsi"] }
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
  version           = "7.5.0"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  name              = "${var.prefix}-vpc"
}

#############################################################################
# Placement group
#############################################################################

resource "ibm_is_placement_group" "placement_group" {
  name           = "${var.prefix}-host-spread"
  resource_group = module.resource_group.resource_group_id
  strategy       = "host_spread"
  tags           = var.resource_tags
}

#############################################################################
# Provision VSI
#############################################################################

module "slz_vsi" {
  source                     = "../../"
  resource_group_id          = module.resource_group.resource_group_id
  image_id                   = var.image_id
  create_security_group      = false
  tags                       = var.resource_tags
  access_tags                = var.access_tags
  subnets                    = module.slz_vpc.subnet_zone_list
  vpc_id                     = module.slz_vpc.vpc_id
  prefix                     = var.prefix
  placement_group_id         = ibm_is_placement_group.placement_group.id
  machine_type               = "cx2-2x4"
  user_data                  = null
  boot_volume_encryption_key = module.key_protect_all_inclusive.keys["slz-vsi.${var.prefix}-vsi"].crn
  existing_kms_instance_guid = module.key_protect_all_inclusive.key_protect_guid
  vsi_per_subnet             = 1
  ssh_key_ids                = [local.ssh_key_id]
  # Add 1 additional data volume to each VSI
  block_storage_volumes = [
    {
      name    = var.prefix
      profile = "10iops-tier"
  }]
  load_balancers = [
    {
      name              = "${var.prefix}-lb"
      type              = "public"
      listener_port     = 9080
      listener_protocol = "http"
      connection_limit  = 100
      algorithm         = "round_robin"
      protocol          = "http"
      health_delay      = 60
      health_retries    = 5
      health_timeout    = 30
      health_type       = "http"
      pool_member_port  = 8080
    }
  ]
}
