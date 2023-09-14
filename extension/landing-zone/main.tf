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

data "ibm_is_vpc" "vpc_by_id" {
  identifier = var.vpc_id
}


data "ibm_is_image" "image" {
  name = var.image_name
}

locals {
  subnets = [
    for subnet in data.ibm_is_vpc.vpc_by_id.subnets :
    subnet if can(regex(join("|", var.subnet_names), subnet.name))
  ]
}

module "vsi" {
  source                        = "../../"
  resource_group_id             = local.resource_group_id
  create_security_group         = var.security_group == null ? false : true
  prefix                        = "${var.prefix}-vsi"
  vpc_id                        = var.vpc_id
  subnets                       = var.subnet_names != null ? local.subnets : data.ibm_is_vpc.vpc_by_id.subnets
  tags                          = var.resource_tags
  access_tags                   = var.access_tags
  kms_encryption_enabled        = true
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  user_data                     = var.user_data
  image_id                      = data.ibm_is_image.image.id
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  existing_kms_instance_guid    = var.existing_kms_instance_guid
  security_group_ids            = var.security_group_ids
  ssh_key_ids                   = [local.ssh_key_id]
  machine_type                  = var.machine_type
  vsi_per_subnet                = var.vsi_per_subnet
  security_group                = var.security_group
  load_balancers                = var.load_balancers
  block_storage_volumes         = var.block_storage_volumes
  enable_floating_ip            = var.enable_floating_ip
}
