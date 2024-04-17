locals {
  # Validation (approach based on https://github.com/hashicorp/terraform/issues/25609#issuecomment-1057614400)
  # tflint-ignore: terraform_unused_declarations
  validate_kms_values = !var.kms_encryption_enabled && var.boot_volume_encryption_key != null ? tobool("When passing values for var.boot_volume_encryption_key, you must set var.kms_encryption_enabled to true. Otherwise unset them to use default encryption") : true
  # tflint-ignore: terraform_unused_declarations
  validate_kms_vars = var.kms_encryption_enabled && var.boot_volume_encryption_key == null ? tobool("When setting var.kms_encryption_enabled to true, a value must be passed for var.boot_volume_encryption_key") : true
  # tflint-ignore: terraform_unused_declarations
  validate_auth_policy = var.kms_encryption_enabled && var.skip_iam_authorization_policy == false && var.existing_kms_instance_guid == null ? tobool("When var.skip_iam_authorization_policy is set to false, and var.kms_encryption_enabled to true, a value must be passed for var.existing_kms_instance_guid in order to create the auth policy.") : true

  # Determine what KMS service is being used for database encryption
  kms_service = var.boot_volume_encryption_key != null ? (
    can(regex(".*kms.*", var.boot_volume_encryption_key)) ? "kms" : (
      can(regex(".*hs-crypto.*", var.boot_volume_encryption_key)) ? "hs-crypto" : null
    )
  ) : null
}

##############################################################################
# Virtual Server Data
##############################################################################
locals {

  # Create list of VSI using subnets and VSI per subnet
  vsi_list = flatten([
    # For each number in a range from 0 to VSI per subnet
    for count in range(var.vsi_per_subnet) : [
      # For each subnet
      for subnet in range(length(var.subnets)) :
      {
        name        = "${var.prefix}-${(count) * length(var.subnets) + subnet + 1}"
        vsi_name    = "${var.prefix}-${format("%03d", count * length(var.subnets) + subnet + 1)}"
        subnet_id   = var.subnets[subnet].id
        zone        = var.subnets[subnet].zone
        subnet_name = var.subnets[subnet].name
      }
    ]
  ])

  # Create map of VSI from list
  vsi_map = {
    for server in local.vsi_list :
    server.name => server
  }

  secondary_fip_list = flatten([
    # For each interface in list of floating ips
    for interface in var.secondary_floating_ips :
    [
      # For each virtual server
      for instance in ibm_is_instance.vsi :
      {
        # fip name
        name = "${instance.name}-${interface}-fip"
        # target interface at the same index as subnet name
        target = instance.network_interfaces[index(var.secondary_subnets[*].name, interface)].id
      }
    ]
  ])
}

# workaround for https://github.com/IBM-Cloud/terraform-provider-ibm/issues/4478
resource "time_sleep" "wait_for_authorization_policy" {
  depends_on = [ibm_iam_authorization_policy.block_storage_policy]

  create_duration = "30s"
}

##############################################################################
# Lookup default security group id in the vpc
##############################################################################

data "ibm_is_vpc" "vpc" {
  identifier = var.vpc_id
}

##############################################################################
# Create Virtual Servers
##############################################################################

# NOTE: The below auth policy cannot be scoped to a source resource group due to
# the fact that the Block storage volume does not yet exist in the resource group.

resource "ibm_iam_authorization_policy" "block_storage_policy" {
  count                       = var.kms_encryption_enabled == false || var.skip_iam_authorization_policy ? 0 : 1
  source_service_name         = "server-protect"
  target_service_name         = local.kms_service
  target_resource_instance_id = var.existing_kms_instance_guid
  roles                       = ["Reader"]
  description                 = "Allow block storage volumes to be encrypted by Key Management instance."
}

resource "ibm_is_instance" "vsi" {
  for_each        = local.vsi_map
  name            = each.value.vsi_name
  image           = (var.boot_volume_snapshot_id == null) ? var.image_id : null # image and snapshot are mutually exclusive
  profile         = var.machine_type
  resource_group  = var.resource_group_id
  vpc             = var.vpc_id
  zone            = each.value.zone
  user_data       = var.user_data
  keys            = var.ssh_key_ids
  placement_group = var.placement_group_id
  tags            = var.tags
  access_tags     = var.access_tags
  lifecycle {
    ignore_changes = [
      image
    ]
  }

  primary_network_interface {
    subnet = each.value.subnet_id
    security_groups = flatten([
      (var.create_security_group ? [ibm_is_security_group.security_group[var.security_group.name].id] : []),
      var.security_group_ids,
      (var.create_security_group == false && length(var.security_group_ids) == 0 ? [data.ibm_is_vpc.vpc.default_security_group] : []),
    ])
    allow_ip_spoofing = var.allow_ip_spoofing
  }

  dynamic "network_interfaces" {
    for_each = {
      for k in var.secondary_subnets : k.zone => k
      if k.zone == each.value.zone
    }
    content {
      subnet = network_interfaces.value.id
      # If security_groups is empty(list is len(0)) then default list to data.ibm_is_vpc.vpc.default_security_group.
      # If list is empty it will fail on reapply as when vsi is passed an empty security group list it will attach the default security group.
      security_groups = length(flatten([
        (var.create_security_group && var.secondary_use_vsi_security_group ? [ibm_is_security_group.security_group[var.security_group.name].id] : []),
        [
          for group in var.secondary_security_groups :
          group.security_group_id if group.interface_name == network_interfaces.value.name
        ]
        ])) == 0 ? [data.ibm_is_vpc.vpc.default_security_group] : flatten([
        (var.create_security_group && var.secondary_use_vsi_security_group ? [ibm_is_security_group.security_group[var.security_group.name].id] : []),
        [
          for group in var.secondary_security_groups :
          group.security_group_id if group.interface_name == network_interfaces.value.name
        ]
      ])
      allow_ip_spoofing = var.secondary_allow_ip_spoofing
    }
  }

  boot_volume {
    encryption = var.boot_volume_encryption_key
    snapshot   = var.boot_volume_snapshot_id
  }

  # Only add volumes if volumes are being created by the module
  volumes = length(var.block_storage_volumes) == 0 ? [] : local.volume_by_vsi[each.key]
}

##############################################################################


##############################################################################
# Optionally create floating IP
##############################################################################

resource "ibm_is_floating_ip" "vsi_fip" {
  for_each       = var.enable_floating_ip ? ibm_is_instance.vsi : {}
  name           = "${each.value.name}-fip"
  target         = each.value.primary_network_interface[0].id
  tags           = var.tags
  access_tags    = var.access_tags
  resource_group = var.resource_group_id
}

resource "ibm_is_floating_ip" "secondary_fip" {
  for_each = length(var.secondary_floating_ips) == 0 ? {} : {
    for interface in local.secondary_fip_list :
    (interface.name) => interface
  }
  name           = each.key
  target         = each.value.target
  tags           = var.tags
  access_tags    = var.access_tags
  resource_group = var.resource_group_id
}

##############################################################################
