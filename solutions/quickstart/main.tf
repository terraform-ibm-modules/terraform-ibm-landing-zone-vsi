#######################################################################################################################
# Resource Group
#######################################################################################################################
module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.3.0"
  existing_resource_group_name = var.existing_resource_group_name
}

locals {
  ssh_key_id = var.existing_ssh_key_name != null ? data.ibm_is_ssh_key.existing_ssh_key[0].id : resource.ibm_is_ssh_key.ssh_key[0].id
  prefix     = var.prefix != null ? trimspace(var.prefix) != "" ? "${var.prefix}-" : "" : ""
}

##############################################################################
# Create new SSH key
##############################################################################

resource "tls_private_key" "tls_key" {
  count     = var.existing_ssh_key_name != null ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "ibm_is_ssh_key" "ssh_key" {
  count      = var.existing_ssh_key_name != null ? 0 : 1
  name       = "${local.prefix}-ssh-key"
  public_key = resource.tls_private_key.tls_key[0].public_key_openssh
}

data "ibm_is_ssh_key" "existing_ssh_key" {
  count = var.existing_ssh_key_name != null ? 1 : 0
  name  = var.existing_ssh_key_name
}

#############################################################################
# Provision VPC
#############################################################################

# module "vpc" {
#   source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
#   version           = "8.0.0"
#   resource_group_id = module.resource_group.resource_group_id
#   region            = var.region
#   prefix            = "${local.prefix}${var.vpc_name}"
#   tags              = var.resource_tags
#   name              = var.vpc_name
# }


########################################################################################################################
# Virtual Server Instance
########################################################################################################################

data "ibm_is_image" "image" {
  name = var.image_name
}

module "existing_vpc_crn_parser" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.2.0"
  crn     = var.existing_vpc_crn
}

data "ibm_is_subnet" "subnet" {
  count      = var.existing_subnet_id != null ? 1 : 0
  identifier = var.existing_subnet_id
}

data "ibm_is_vpc" "vpc" {
  identifier = local.existing_vpc_id
}
locals {

  existing_vpc_id = module.existing_vpc_crn_parser.resource

  # When `existing_subnet_id` is not provided, use the first subnet from the existing VPC.
  subnet = var.existing_subnet_id != null ? [{
    name = data.ibm_is_subnet.subnet[0].name
    id   = data.ibm_is_subnet.subnet[0].id
    zone = data.ibm_is_subnet.subnet[0].zone
    }] : [{
    name = data.ibm_is_vpc.vpc.subnets[0].name
    id   = data.ibm_is_vpc.vpc.subnets[0].id
    zone = data.ibm_is_vpc.vpc.subnets[0].zone
  }]
}

module "vsi" {
  source                = "../../"
  resource_group_id     = module.resource_group.resource_group_id
  image_id              = data.ibm_is_image.image.id
  create_security_group = true
  tags                  = var.resource_tags
  access_tags           = var.access_tags
  subnets               = local.subnet
  vpc_id                = local.existing_vpc_id
  prefix                = "${local.prefix}${var.vsi_name}"
  machine_type          = var.machine_type
  user_data             = var.user_data
  vsi_per_subnet        = 1
  ssh_key_ids           = [local.ssh_key_id]
  enable_floating_ip    = var.enable_floating_ip
}
