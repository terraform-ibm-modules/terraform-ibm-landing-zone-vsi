#######################################################################################################################
# Resource Group
#######################################################################################################################
module "resource_group" {
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.1.6"
  existing_resource_group_name = var.existing_resource_group_name
}

data "ibm_is_subnet" "subnet" {
  identifier = var.existing_subnet_id
}

data "ibm_is_subnet" "secondary_subnet" {
  count      = var.existing_secondary_subnet_id != null ? 1 : 0
  identifier = var.existing_secondary_subnet_id
}

locals {
  prefix = var.prefix != null ? trimspace(var.prefix) != "" ? "${var.prefix}-" : "" : ""

  subnet = [{
    name = data.ibm_is_subnet.subnet.name
    id   = data.ibm_is_subnet.subnet.id
    zone = data.ibm_is_subnet.subnet.zone
  }]

  secondary_subnet = var.existing_secondary_subnet_id != null ? [{
    name = data.ibm_is_subnet.secondary_subnet[0].name
    id   = data.ibm_is_subnet.secondary_subnet[0].id
    zone = data.ibm_is_subnet.secondary_subnet[0].zone
  }] : []

  ssh_keys = concat(var.existing_ssh_key_ids, var.ssh_public_key != null ? [ibm_is_ssh_key.ssh_key[0].id] : [])

  custom_vsi_volume_names = { (data.ibm_is_subnet.subnet.name) = {
  "${local.prefix}${var.vsi_name}" = [for block in var.block_storage_volumes : block.name] } }
}


##############################################################################
# Create New SSH Key
##############################################################################

resource "ibm_is_ssh_key" "ssh_key" {
  count          = var.ssh_public_key != null ? 1 : 0
  name           = "${local.prefix}${var.vsi_name}-ssh-key"
  public_key     = replace(var.ssh_public_key, "/==.*$/", "==")
  resource_group = module.resource_group.resource_group_id
  tags           = var.resource_tags
}


########################################################################################################################
# Virtual Server Instance
########################################################################################################################

module "vsi" {
  source                           = "../../"
  resource_group_id                = module.resource_group.resource_group_id
  prefix                           = "${local.prefix}${var.vsi_name}"
  tags                             = var.resource_tags
  vpc_id                           = var.existing_vpc_id
  subnets                          = local.subnet
  image_id                         = var.image_id
  ssh_key_ids                      = local.ssh_keys
  machine_type                     = var.machine_type
  vsi_per_subnet                   = 1
  user_data                        = var.user_data
  existing_kms_instance_guid       = var.existing_kms_instance_guid
  skip_iam_authorization_policy    = var.skip_iam_authorization_policy
  boot_volume_encryption_key       = var.boot_volume_encryption_key
  use_boot_volume_key_as_default   = var.use_boot_volume_key_as_default
  kms_encryption_enabled           = var.kms_encryption_enabled
  manage_reserved_ips              = var.manage_reserved_ips
  use_static_boot_volume_name      = var.use_static_boot_volume_name
  enable_floating_ip               = var.enable_floating_ip
  allow_ip_spoofing                = var.allow_ip_spoofing
  create_security_group            = var.create_security_group
  security_group                   = var.security_group
  security_group_ids               = var.security_group_ids
  block_storage_volumes            = var.block_storage_volumes
  load_balancers                   = var.load_balancers
  access_tags                      = var.access_tags
  snapshot_consistency_group_id    = var.snapshot_consistency_group_id
  boot_volume_snapshot_id          = var.boot_volume_snapshot_id
  enable_dedicated_host            = var.enable_dedicated_host
  dedicated_host_id                = var.dedicated_host_id
  use_legacy_network_interface     = var.use_legacy_network_interface
  secondary_allow_ip_spoofing      = var.secondary_allow_ip_spoofing
  secondary_floating_ips           = var.secondary_floating_ips
  secondary_security_groups        = var.secondary_security_groups
  secondary_use_vsi_security_group = var.secondary_use_vsi_security_group
  secondary_subnets                = local.secondary_subnet
  placement_group_id               = var.placement_group_id
  primary_vni_additional_ip_count  = var.primary_vni_additional_ip_count
  custom_vsi_volume_names          = local.custom_vsi_volume_names
}
