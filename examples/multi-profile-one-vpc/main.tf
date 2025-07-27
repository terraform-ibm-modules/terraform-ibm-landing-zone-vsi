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
  version = "1.2.1"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

##############################################################################
# Key Protect All Inclusive
##############################################################################

module "key_protect_all_inclusive" {
  source                    = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                   = "5.1.14"
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

module "existing_boot_volume_kms_key_crn_parser" {
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.2.0"
  crn     = module.key_protect_all_inclusive.keys["slz-vsi.${var.prefix}-vsi"].crn
}

locals {
  existing_kms_guid = module.existing_boot_volume_kms_key_crn_parser.service_instance
  kms_service_name  = module.existing_boot_volume_kms_key_crn_parser.service_name
  kms_account_id    = module.existing_boot_volume_kms_key_crn_parser.account_id
  kms_key_id        = module.existing_boot_volume_kms_key_crn_parser.resource
}

# NOTE: The below auth policy cannot be scoped to a source resource group due to
# the fact that the Block storage volume does not yet exist in the resource group.
resource "ibm_iam_authorization_policy" "block_storage_policy" {
  source_service_name = "server-protect"
  roles               = ["Reader"]
  description         = "Allow block storage volumes to read the ${local.kms_service_name} key ${local.kms_key_id} from the instance ${local.existing_kms_guid}"
  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = local.kms_service_name
  }
  resource_attributes {
    name     = "accountId"
    operator = "stringEquals"
    value    = local.kms_account_id
  }
  resource_attributes {
    name     = "serviceInstance"
    operator = "stringEquals"
    value    = local.existing_kms_guid
  }
  resource_attributes {
    name     = "resourceType"
    operator = "stringEquals"
    value    = "key"
  }
  resource_attributes {
    name     = "resource"
    operator = "stringEquals"
    value    = local.kms_key_id
  }
  # Scope of policy now includes the key, so ensure to create new policy before
  # destroying old one to prevent any disruption to every day services.
  lifecycle {
    create_before_destroy = true
  }
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
  version           = "7.25.12"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  prefix            = var.prefix
  tags              = var.resource_tags
  name              = "vpc"
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
  resource_group  = module.resource_group.resource_group_id
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
  name           = "${var.prefix}-sg"
  vpc            = module.slz_vpc.vpc_id
  resource_group = module.resource_group.resource_group_id
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

#############################################################################
# First VSI on cx2
#############################################################################

module "slz_vsi_cx" {
  depends_on                      = [module.slz_vpc]
  source                          = "../../"
  resource_group_id               = module.resource_group.resource_group_id
  image_id                        = var.image_id
  create_security_group           = false
  tags                            = var.resource_tags
  access_tags                     = var.access_tags
  subnets                         = module.slz_vpc.subnet_zone_list
  vpc_id                          = module.slz_vpc.vpc_id
  prefix                          = "${var.prefix}-cx"
  machine_type                    = "cx2-2x4"
  user_data                       = null
  boot_volume_encryption_key      = module.key_protect_all_inclusive.keys["slz-vsi.${var.prefix}-vsi"].crn
  skip_iam_authorization_policy   = true # is done globally above
  use_static_boot_volume_name     = true
  boot_volume_size                = 150
  kms_encryption_enabled          = true
  vsi_per_subnet                  = 1
  primary_vni_additional_ip_count = 2
  manage_reserved_ips             = true

  ssh_key_ids               = [local.ssh_key_id]
  secondary_subnets         = local.secondary_subnet_zone_list
  secondary_security_groups = local.secondary_security_groups

  # Create a floating IPs for the additional VNI
  secondary_floating_ips = [
    for subnet in local.secondary_subnet_zone_list :
    subnet.name
  ]

  # Create a floating IP for each virtual server created
  enable_floating_ip               = true
  secondary_use_vsi_security_group = true

  # Add 1 additional data volume to each VSI
  block_storage_volumes = [
    {
      name    = var.prefix
      profile = "10iops-tier"
  }]
  load_balancers = [
    {
      name                    = "${var.prefix}-cx-lb"
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
      name              = "${var.prefix}-cx-nlb"
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

#############################################################################
# Second VSI with Placement Group on bx2
#############################################################################

module "slz_vsi_bx" {
  depends_on                      = [module.slz_vpc]
  source                          = "../../"
  resource_group_id               = module.resource_group.resource_group_id
  image_id                        = var.image_id
  create_security_group           = false
  tags                            = var.resource_tags
  access_tags                     = var.access_tags
  subnets                         = module.slz_vpc.subnet_zone_list
  vpc_id                          = module.slz_vpc.vpc_id
  prefix                          = "${var.prefix}-bx"
  machine_type                    = "bx2-2x8"
  user_data                       = null
  boot_volume_encryption_key      = module.key_protect_all_inclusive.keys["slz-vsi.${var.prefix}-vsi"].crn
  skip_iam_authorization_policy   = true # is done globally above
  use_static_boot_volume_name     = true
  boot_volume_size                = 150
  kms_encryption_enabled          = true
  vsi_per_subnet                  = 1
  primary_vni_additional_ip_count = 2
  manage_reserved_ips             = true

  ssh_key_ids               = [local.ssh_key_id]
  secondary_subnets         = local.secondary_subnet_zone_list
  secondary_security_groups = local.secondary_security_groups

  # Create a floating IPs for the additional VNI
  secondary_floating_ips = [
    for subnet in local.secondary_subnet_zone_list :
    subnet.name
  ]

  # Create a floating IP for each virtual server created
  enable_floating_ip               = true
  secondary_use_vsi_security_group = true

  # Add 1 additional data volume to each VSI
  block_storage_volumes = [
    {
      name    = var.prefix
      profile = "10iops-tier"
  }]
  load_balancers = [
    {
      name                    = "${var.prefix}-bx-lb"
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
      name              = "${var.prefix}-bx-nlb"
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
