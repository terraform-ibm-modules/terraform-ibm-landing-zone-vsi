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
  version = "1.1.6"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Key Protect All Inclusive
##############################################################################

module "key_protect_all_inclusive" {
  source                    = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                   = "4.15.8"
  resource_group_id         = module.resource_group.resource_group_id
  region                    = var.region
  key_protect_instance_name = "${var.prefix}-kp"
  resource_tags             = var.resource_tags
  keys = [
    {
      key_ring_name = "slz-vsi"
      keys = [
        {
          key_name     = "${var.prefix}-vsi"
          force_delete = true
        }
      ]
    }
  ]
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
  version           = "7.19.0"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  name              = "vpc"
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
# Provision Secondary Subnets
#############################################################################

locals {
  secondary_subnet_map = {
    "${var.prefix}-second-subnet-a" = {
      zone = "${var.region}-1"
      cidr = "10.10.20.0/24"
    }
    "${var.prefix}-second-subnet-b" = {
      zone = "${var.region}-2"
      cidr = "10.20.20.0/24"
    }
    "${var.prefix}-second-subnet-c" = {
      zone = "${var.region}-3"
      cidr = "10.30.20.0/24"
    }
  }
}

resource "ibm_is_vpc_address_prefix" "secondary_address_prefixes" {
  for_each = local.secondary_subnet_map
  name     = "${each.key}-prefix"
  vpc      = module.slz_vpc.vpc_id
  zone     = each.value.zone
  cidr     = each.value.cidr
}

resource "ibm_is_subnet" "secondary_subnet" {
  depends_on      = [ibm_is_vpc_address_prefix.secondary_address_prefixes]
  for_each        = local.secondary_subnet_map
  ipv4_cidr_block = each.value.cidr
  name            = each.key
  vpc             = module.slz_vpc.vpc_id
  zone            = each.value.zone
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
  name = "${var.prefix}-sg"
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
  kms_encryption_enabled     = true
  existing_kms_instance_guid = module.key_protect_all_inclusive.kms_guid
  vsi_per_subnet             = 1
  ssh_key_ids                = [local.ssh_key_id]
  secondary_subnets          = local.secondary_subnet_zone_list
  secondary_security_groups  = local.secondary_security_groups
  # Create a floating IP for each virtual server created
  enable_floating_ip               = true
  secondary_use_vsi_security_group = var.secondary_use_vsi_security_group
  # Add 1 additional data volume to each VSI
  block_storage_volumes = [
    {
      name    = var.prefix
      profile = "10iops-tier"
  }]
  load_balancers = [
    {
      name                    = "${var.prefix}-lb"
      type                    = "public"
      listener_port           = 9080
      listener_protocol       = "http"
      connection_limit        = 100
      idle_connection_timeout = 50
      algorithm               = "round_robin"
      protocol                = "http"
      health_delay            = 60
      health_retries          = 5
      health_timeout          = 30
      health_type             = "http"
      pool_member_port        = 8080
    },
    {
      name              = "${var.prefix}-nlb"
      type              = "public"
      profile           = "network-fixed"
      listener_port     = 3128
      listener_protocol = "tcp"
      algorithm         = "round_robin"
      protocol          = "tcp"
      health_delay      = 60
      health_retries    = 5
      health_timeout    = 30
      health_type       = "tcp"
      pool_member_port  = 3120
    }
  ]
}
