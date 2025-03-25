#######################################################################################################################
# Resource Group
#######################################################################################################################
module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.1.6"
  existing_resource_group_name = var.existing_resource_group_name
}

#######################################################################################################################
# KMS Key
#######################################################################################################################

module "existing_kms_crn_parser" {
  count   = var.existing_kms_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_kms_instance_crn
}

module "existing_boot_volume_kms_key_crn_parser" {
  count   = var.existing_boot_volume_kms_key_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_boot_volume_kms_key_crn
}

locals {
  boot_volume_key_ring_name        = "${local.prefix}${var.boot_volume_key_ring_name}"
  boot_volume_key_name             = "${local.prefix}${var.boot_volume_key_name}"
  kms_region                       = var.existing_kms_instance_crn != null ? module.existing_kms_crn_parser[0].region : var.existing_boot_volume_kms_key_crn != null ? module.existing_boot_volume_kms_key_crn_parser[0].region : null
  existing_kms_guid                = var.existing_kms_instance_crn != null ? module.existing_kms_crn_parser[0].service_instance : var.existing_boot_volume_kms_key_crn != null ? module.existing_boot_volume_kms_key_crn_parser[0].service_instance : null
  kms_service_name                 = var.existing_kms_instance_crn != null ? module.existing_kms_crn_parser[0].service_name : var.existing_boot_volume_kms_key_crn != null ? module.existing_boot_volume_kms_key_crn_parser[0].service_name : null
  kms_account_id                   = var.existing_kms_instance_crn != null ? module.existing_kms_crn_parser[0].account_id : var.existing_boot_volume_kms_key_crn != null ? module.existing_boot_volume_kms_key_crn_parser[0].account_id : null
  kms_key_id                       = var.existing_kms_instance_crn != null ? module.kms[0].keys[format("%s.%s", local.boot_volume_key_ring_name, local.boot_volume_key_name)].key_id : var.existing_boot_volume_kms_key_crn != null ? module.existing_boot_volume_kms_key_crn_parser[0].resource : null
  boot_volume_kms_key_crn          = var.kms_encryption_enabled_boot_volume ? var.existing_boot_volume_kms_key_crn != null ? var.existing_boot_volume_kms_key_crn : module.kms[0].keys[format("%s.%s", local.boot_volume_key_ring_name, local.boot_volume_key_name)].crn : null
  create_cross_account_auth_policy = !var.skip_block_storage_kms_iam_auth_policy && var.ibmcloud_kms_api_key == null ? false : (data.ibm_iam_account_settings.iam_account_settings.account_id != local.kms_account_id)
}


data "ibm_iam_account_settings" "iam_account_settings" {
}


resource "ibm_iam_authorization_policy" "block_storage_kms_policy" {
  count                  = local.create_cross_account_auth_policy ? 1 : 0
  provider               = ibm.kms
  source_service_account = data.ibm_iam_account_settings.iam_account_settings.account_id
  source_service_name    = "server-protect"
  roles                  = ["Reader"]
  description            = "Allow block storage volumes to be encrypted by Key Management instance."
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

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_authorization_policy" {
  depends_on = [ibm_iam_authorization_policy.block_storage_kms_policy]
  count      = local.create_cross_account_auth_policy ? 1 : 0

  create_duration = "30s"
}

# KMS root key for SCC COS bucket
module "kms" {
  providers = {
    ibm = ibm.kms
  }
  count                       = var.kms_encryption_enabled_boot_volume && var.existing_boot_volume_kms_key_crn == null ? 1 : 0
  source                      = "terraform-ibm-modules/kms-all-inclusive/ibm"
  version                     = "4.21.2"
  create_key_protect_instance = false
  region                      = local.kms_region
  existing_kms_instance_crn   = var.existing_kms_instance_crn
  key_ring_endpoint_type      = var.kms_endpoint_type
  key_endpoint_type           = var.kms_endpoint_type
  keys = [
    {
      key_ring_name     = local.boot_volume_key_ring_name
      existing_key_ring = false
      keys = [
        {
          key_name                 = local.boot_volume_key_name
          standard_key             = false
          rotation_interval_month  = 3
          dual_auth_delete_enabled = false
          force_delete             = var.force_delete_kms_key
        }
      ]
    }
  ]
}

#######################################################################################################################
# VSI
#######################################################################################################################
data "ibm_is_subnet" "subnet" {
  count      = var.existing_subnet_id != null ? 1 : 0
  identifier = var.existing_subnet_id
}

data "ibm_is_vpc" "vpc" {
  count      = var.existing_vpc_id != null ? 1 : 0
  identifier = var.existing_vpc_id
}

data "ibm_is_subnet" "secondary_subnet" {
  count      = var.existing_secondary_subnet_id != null ? 1 : 0
  identifier = var.existing_secondary_subnet_id
}

locals {
  prefix = var.prefix != null ? trimspace(var.prefix) != "" ? "${var.prefix}-" : "" : ""

  subnet = var.existing_subnet_id != null ? [{
    name = data.ibm_is_subnet.subnet[0].name
    id   = data.ibm_is_subnet.subnet[0].id
    zone = data.ibm_is_subnet.subnet[0].zone
    }] : [{
    name = data.ibm_is_vpc.vpc[0].subnets[0].name
    id   = data.ibm_is_vpc.vpc[0].subnets[0].id
    zone = data.ibm_is_vpc.vpc[0].subnets[0].zone
  }]

  secondary_subnet = var.existing_secondary_subnet_id != null ? [{
    name = data.ibm_is_subnet.secondary_subnet[0].name
    id   = data.ibm_is_subnet.secondary_subnet[0].id
    zone = data.ibm_is_subnet.secondary_subnet[0].zone
  }] : []

  ssh_keys = var.auto_generate_ssh_key ? [ibm_is_ssh_key.auto_generate_ssh_key[0].id] : concat(var.existing_ssh_key_ids, length(var.ssh_public_keys) > 0 ? [for ssh in ibm_is_ssh_key.ssh_key : ssh.id] : [])

  custom_vsi_volume_names = { (var.existing_subnet_id != null ? data.ibm_is_subnet.subnet[0].name : data.ibm_is_vpc.vpc[0].subnets[0].name) = {
  "${local.prefix}${var.vsi_name}" = [for block in var.block_storage_volumes : block.name] } }
}


##############################################################################
# Create New SSH Key
##############################################################################

resource "ibm_is_ssh_key" "ssh_key" {
  for_each = { for idx, ssh in var.ssh_public_keys :
  idx => ssh }
  name           = "${local.prefix}${var.vsi_name}-ssh-key-${each.key}"
  public_key     = replace(each.value, "/==.*$/", "==")
  resource_group = module.resource_group.resource_group_id
  tags           = var.vsi_resource_tags
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

########################################################################################################################
# Virtual Server Instance
########################################################################################################################

module "vsi" {
  source                           = "../../"
  depends_on                       = [time_sleep.wait_for_authorization_policy[0]]
  resource_group_id                = module.resource_group.resource_group_id
  prefix                           = "${local.prefix}${var.vsi_name}"
  tags                             = var.vsi_resource_tags
  vpc_id                           = var.existing_vpc_id != null ? var.existing_vpc_id : data.ibm_is_subnet.subnet[0].vpc
  subnets                          = local.subnet
  image_id                         = var.image_id
  ssh_key_ids                      = local.ssh_keys
  machine_type                     = var.machine_type
  vsi_per_subnet                   = 1
  user_data                        = var.user_data
  existing_kms_instance_guid       = local.existing_kms_guid
  skip_iam_authorization_policy    = local.create_cross_account_auth_policy ? false : var.skip_block_storage_kms_iam_auth_policy
  boot_volume_encryption_key       = local.boot_volume_kms_key_crn
  use_boot_volume_key_as_default   = var.use_boot_volume_key_as_default
  kms_encryption_enabled           = var.kms_encryption_enabled_boot_volume
  manage_reserved_ips              = var.manage_reserved_ips
  use_static_boot_volume_name      = var.use_static_boot_volume_name
  enable_floating_ip               = var.enable_floating_ip
  allow_ip_spoofing                = var.allow_ip_spoofing
  create_security_group            = var.security_group != null ? true : false
  security_group                   = var.security_group
  security_group_ids               = var.security_group_ids
  block_storage_volumes            = var.block_storage_volumes
  load_balancers                   = var.load_balancers
  access_tags                      = var.vsi_access_tags
  snapshot_consistency_group_id    = var.snapshot_consistency_group_id
  boot_volume_snapshot_id          = var.boot_volume_snapshot_id
  enable_dedicated_host            = var.dedicated_host_id != null ? true : false
  dedicated_host_id                = var.dedicated_host_id
  use_legacy_network_interface     = false
  secondary_allow_ip_spoofing      = var.secondary_allow_ip_spoofing
  secondary_floating_ips           = var.secondary_floating_ips
  secondary_security_groups        = var.secondary_security_groups
  secondary_use_vsi_security_group = var.secondary_use_vsi_security_group
  secondary_subnets                = local.secondary_subnet
  placement_group_id               = var.placement_group_id
  primary_vni_additional_ip_count  = var.primary_virtual_network_interface_additional_ip_count
  custom_vsi_volume_names          = local.custom_vsi_volume_names
}

########################################################################################################################
# Secret Mananger
########################################################################################################################

module "existing_secret_manager_crn_parser" {
  count   = var.existing_secrets_manager_instance_crn != null ? 1 : 0
  source  = "terraform-ibm-modules/common-utilities/ibm//modules/crn-parser"
  version = "1.1.0"
  crn     = var.existing_secrets_manager_instance_crn
}
locals {
  existing_secrets_manager_instance_guid   = var.existing_secrets_manager_instance_crn != null ? module.existing_secret_manager_crn_parser[0].service_instance : null
  existing_secrets_manager_instance_region = var.existing_secrets_manager_instance_crn != null ? module.existing_secret_manager_crn_parser[0].region : null
}

module "secrets_manager_service_credentials" {
  count                       = var.auto_generate_ssh_key ? 1 : 0
  source                      = "terraform-ibm-modules/secrets-manager/ibm//modules/secrets"
  version                     = "1.25.5"
  existing_sm_instance_guid   = local.existing_secrets_manager_instance_guid
  existing_sm_instance_region = local.existing_secrets_manager_instance_region
  endpoint_type               = var.existing_secrets_manager_endpoint_type
  secrets = [{
    secret_group_name        = "${local.prefix}${var.ssh_key_secret_group_name}"
    secret_group_description = "The ssh private key secret group."
    secrets = [
      {
        secret_name             = "${local.prefix}${var.ssh_key_secret_name}"
        secret_description      = "The ssh private key data in [PEM (RFC 1421)](https://datatracker.ietf.org/doc/html/rfc1421) format."
        secret_type             = "arbitrary"
        secret_payload_password = tls_private_key.auto_generate_ssh_key[0].private_key_pem
      }
    ]
  }]
}
