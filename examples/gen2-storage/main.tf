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
  version = "1.4.0"
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
  version           = "8.9.2"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  name              = "vpc"
}

#############################################################################
# Provision VSI
# using Gen2 boot volume storage type (sdp) with custom IOPS setting
#############################################################################

data "ibm_is_image" "centos_10" {
  name = "ibm-centos-stream-10-amd64-4"
}

module "slz_vsi" {
  source                = "../../"
  resource_group_id     = module.resource_group.resource_group_id
  image_id              = data.ibm_is_image.centos_10.id
  create_security_group = false
  tags                  = var.resource_tags
  access_tags           = var.access_tags
  subnets               = module.slz_vpc.subnet_zone_list
  vpc_id                = module.slz_vpc.vpc_id
  prefix                = var.prefix
  machine_type          = "cx2-2x4"
  user_data             = null
  vsi_per_subnet        = 1
  ssh_key_ids           = [local.ssh_key_id]
  boot_volume_profile   = "sdp"
  boot_volume_size      = 200
  boot_volume_iops      = 5000
}
