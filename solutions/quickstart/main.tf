#######################################################################################################################
# Resource Group
#######################################################################################################################
module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.3.0"
  existing_resource_group_name = var.existing_resource_group_name
}

locals {
  ssh_keys = concat(var.existing_ssh_key_ids, length(var.ssh_public_keys) > 0 ? [for ssh in ibm_is_ssh_key.ssh_key : ssh.id] : [], var.auto_generate_ssh_key ? [ibm_is_ssh_key.auto_generate_ssh_key[0].id] : [])
  prefix   = var.prefix != null ? trimspace(var.prefix) != "" ? "${var.prefix}-" : "" : ""
}

##############################################################################
# Create new SSH key
##############################################################################

resource "ibm_is_ssh_key" "ssh_key" {
  for_each = { for idx, ssh in var.ssh_public_keys :
  idx => ssh }
  name           = "${local.prefix}${var.vsi_name}-ssh-key-${each.key}"
  public_key     = replace(each.value, "/==.*$/", "==")
  resource_group = module.resource_group.resource_group_id
  tags           = var.resource_tags
}

resource "tls_private_key" "auto_generate_ssh_key" {
  count     = var.auto_generate_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "ibm_is_ssh_key" "auto_generate_ssh_key" {
  count      = var.auto_generate_ssh_key ? 1 : 0
  name       = "${var.prefix}${var.vsi_name}-ssh-key"
  public_key = resource.tls_private_key.auto_generate_ssh_key[0].public_key_openssh
}

#############################################################################
# Provision VPC
#############################################################################

module "vpc" {
  source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version           = "8.0.0"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = "${local.prefix}${var.vpc_name}"
  tags              = var.resource_tags
  name              = var.vpc_name
}

########################################################################################################################
# Virtual Server Instance
########################################################################################################################

module "vsi" {
  source                = "../../"
  resource_group_id     = module.resource_group.resource_group_id
  image_id              = var.image_id
  create_security_group = var.security_group != null ? true : false
  security_group        = var.security_group
  tags                  = var.resource_tags
  access_tags           = var.access_tags
  subnets               = module.vpc.subnet_zone_list
  vpc_id                = module.vpc.vpc_id
  prefix                = "${local.prefix}${var.vsi_name}"
  placement_group_id    = var.placement_group_id
  machine_type          = var.machine_type
  user_data             = var.user_data
  vsi_per_subnet        = 1
  ssh_key_ids           = local.ssh_keys
  enable_floating_ip    = var.enable_floating_ip
}
