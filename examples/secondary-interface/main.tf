##############################################################################
# Locals
##############################################################################

locals {
  resource_group_id = var.resource_group != null ? data.ibm_resource_group.existing_resource_group[0].id : ibm_resource_group.resource_group[0].id
  ssh_key_id        = var.ssh_key != null ? data.ibm_is_ssh_key.existing_ssh_key[0].id : resource.ibm_is_ssh_key.ssh_key[0].id
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
  version           = "7.4.2"
  resource_group_id = local.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  name              = var.vpc_name
}

#############################################################################
# Provision Secondary Subnets
#############################################################################

locals {
  subnet_map = {
    for subnet in module.slz_vpc.subnet_zone_list :
    subnet.name => subnet
  }
}

resource "ibm_is_subnet" "secondary_subnet" {
  for_each                 = local.subnet_map
  total_ipv4_address_count = 256
  name                     = "secondary-subnet-${each.value.zone}"
  vpc                      = module.slz_vpc.vpc_id
  zone                     = each.value.zone
}

#############################################################################
# Provision Secondary Security Groups
#############################################################################

locals {
  secondary_security_groups = [
    for subnet in module.slz_vpc.subnet_zone_list : {
      security_group_id = ibm_is_security_group.secondary_security_group.id
      interface_name    = "secondary-subnet-${subnet.zone}"
    }
  ]
}

resource "ibm_is_security_group" "secondary_security_group" {
  name = var.security_group_name
  vpc  = module.slz_vpc.vpc_id
}

#############################################################################
# Provision VSI
#############################################################################

locals {
  secondary_subnet_zone_list = [
    for subnet in ibm_is_subnet.secondary_subnet : {
      name = subnet.name
      id   = subnet.id
      zone = subnet.zone
      cidr = subnet.ipv4_cidr_block
    }
  ]
}

module "slz_vsi" {
  source                           = "../../"
  resource_group_id                = local.resource_group_id
  image_id                         = var.image_id
  create_security_group            = var.create_security_group
  tags                             = var.resource_tags
  access_tags                      = var.access_tags
  subnets                          = module.slz_vpc.subnet_zone_list
  vpc_id                           = module.slz_vpc.vpc_id
  prefix                           = var.prefix
  machine_type                     = var.machine_type
  user_data                        = var.user_data
  vsi_per_subnet                   = var.vsi_per_subnet
  ssh_key_ids                      = [local.ssh_key_id]
  secondary_subnets                = local.secondary_subnet_zone_list
  secondary_security_groups        = local.secondary_security_groups
  secondary_use_vsi_security_group = var.secondary_use_vsi_security_group
}
