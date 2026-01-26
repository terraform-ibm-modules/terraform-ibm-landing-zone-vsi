#######################################################################################################################
# Resource Group
#######################################################################################################################
module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.4.7"
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

module "vpc" {
  count             = var.existing_vpc_crn != null ? 0 : 1
  source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version           = "8.12.5"
  resource_group_id = module.resource_group.resource_group_id
  region            = local.vpc_region
  prefix            = local.prefix
  tags              = var.resource_tags
  subnets = {
    zone-1 = [
      {
        name           = "subnet-a"
        cidr           = "10.10.10.0/24"
        public_gateway = true
        acl_name       = "vpc-acl"
        no_addr_prefix = false
      }
  ] }
  name = "${local.prefix}-qs-vpc"
  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules = [
        {
          name      = "allow-all-22-inbound"
          action    = "allow"
          direction = "inbound"
          tcp = {
            port_min        = 22
            port_max        = 22
            source_port_min = 1024
            source_port_max = 65535
          }
          destination = "0.0.0.0/0"
          source      = "0.0.0.0/0"
        },
        {
          name      = "allow-ephemeral-outbound"
          action    = "allow"
          direction = "outbound"
          tcp = {
            source_port_min = 1
            source_port_max = 65535
            port_min        = 1024
            port_max        = 65535
          }
          destination = "0.0.0.0/0"
          source      = "0.0.0.0/0"
        }
      ]
    }
  ]
}

########################################################################################################################
# Virtual Server Instance
########################################################################################################################

data "ibm_is_image" "image" {
  name = var.image_name
}

module "existing_vpc_crn_parser" {
  count   = var.existing_vpc_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.4.1"
  crn     = var.existing_vpc_crn
}

data "ibm_is_vpc" "vpc" {
  count      = var.existing_vpc_crn != null ? 1 : 0
  identifier = local.vpc_id
}

locals {

  vpc_region = var.existing_vpc_crn != null ? module.existing_vpc_crn_parser[0].region : var.vpc_region
  vpc_id     = var.existing_vpc_crn != null ? module.existing_vpc_crn_parser[0].resource : module.vpc[0].vpc_id

  subnet = var.existing_vpc_crn != null ? [{
    name = data.ibm_is_vpc.vpc[0].subnets[0].name
    id   = data.ibm_is_vpc.vpc[0].subnets[0].id
    zone = data.ibm_is_vpc.vpc[0].subnets[0].zone
  }] : module.vpc[0].subnet_zone_list

  machine_config = {
    mini   = "bx2d-2x8"
    small  = "cx2d-2x4"
    medium = "mx2d-2x16"
    large  = "vx3d-2x32"
  }

  machine_type = lookup(local.machine_config, var.size, local.machine_config[var.size])
}

module "vsi" {
  source                = "../../"
  resource_group_id     = module.resource_group.resource_group_id
  image_id              = data.ibm_is_image.image.id
  tags                  = var.resource_tags
  access_tags           = var.access_tags
  subnets               = local.subnet
  vpc_id                = local.vpc_id
  prefix                = "${local.prefix}${var.vsi_name}"
  machine_type          = local.machine_type
  user_data             = var.user_data
  vsi_per_subnet        = 1
  ssh_key_ids           = [local.ssh_key_id]
  enable_floating_ip    = var.enable_floating_ip
  create_security_group = true
  security_group = {
    name = "ssh-security-group"
    rules = [
      {
        name      = "allow-ssh-inbound"
        direction = "inbound"
        source    = "0.0.0.0/0"
        tcp = {
          port_min = 22
          port_max = 22
        }
      }
    ]
  }
}
