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
        name        = "${var.subnets[subnet].name}-${count}"
        vsi_name    = "${var.prefix}-${substr(var.subnets[subnet].id, -4, 4)}-${format("%03d", count + 1)}"
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

  # List of additional private IP addresses to bind to the primary virtual network interface.
  secondary_reserved_ips_list = flatten([
    for count in range(var.primary_vni_additional_ip_count) : [
      for vsi_key, vsi_value in local.vsi_map :
      {
        name      = "${vsi_key}-${count}"
        subnet_id = vsi_value.subnet_id
      }
    ]
  ])

  secondary_reserved_ips_map = {
    for ip in local.secondary_reserved_ips_list :
    ip.name => ip
  }

  # Old approach to create floating IPs for the secondary network interface.
  legacy_secondary_fip_list = var.use_legacy_network_interface ? flatten([
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
  ]) : []

  # List of secondary Virtual network interface for which floating IPs needs to be added.
  secondary_fip_list = !var.use_legacy_network_interface && length(var.secondary_floating_ips) != 0 ? flatten([
    for instance in ibm_is_instance.vsi : [
      for network_attachment in instance.network_attachments :
      network_attachment if contains([for subnet in var.secondary_floating_ips : subnet], network_attachment.name)
    ]
  ]) : []

  secondary_fip_map = {
    for vni in local.secondary_fip_list :
    vni.name => {
      vni_name    = vni.virtual_network_interface[0].name
      subnet_name = vni.name
      vni_id      = vni.virtual_network_interface[0].id
    }
  }

  # determine snapshot in following order: input variable -> from consistency group -> null (none)
  vsi_boot_volume_snapshot_id = try(coalesce(var.boot_volume_snapshot_id, local.consistency_group_boot_snapshot_id), null)
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
# Create Virtual Network Interface
##############################################################################
resource "ibm_is_virtual_network_interface" "primary_vni" {
  for_each = { for vsi_key, vsi_value in local.vsi_map : vsi_key => vsi_value if !var.use_legacy_network_interface }
  name     = "${each.value.vsi_name}-vni"
  subnet   = each.value.subnet_id
  security_groups = flatten([
    (var.create_security_group ? [ibm_is_security_group.security_group[var.security_group.name].id] : []),
    var.security_group_ids,
    (var.create_security_group == false && length(var.security_group_ids) == 0 ? [data.ibm_is_vpc.vpc.default_security_group] : []),
  ])
  allow_ip_spoofing         = var.allow_ip_spoofing
  auto_delete               = false
  enable_infrastructure_nat = true
  dynamic "primary_ip" {
    for_each = var.manage_reserved_ips ? [1] : []
    content {
      reserved_ip = ibm_is_subnet_reserved_ip.vsi_ip[each.value.name].reserved_ip
    }
  }
  dynamic "ips" {
    for_each = var.primary_vni_additional_ip_count > 0 ? { for count in range(var.primary_vni_additional_ip_count) : count => count } : {}
    content {
      reserved_ip = ibm_is_subnet_reserved_ip.secondary_vsi_ip["${each.value.name}-${ips.key}"].reserved_ip
    }
  }
}

resource "ibm_is_virtual_network_interface" "secondary_vni" {
  for_each = { for k in var.secondary_subnets : k.zone => k if !var.use_legacy_network_interface }
  name     = each.value.name
  subnet   = each.value.id
  # If security_groups is empty(list is len(0)) then default list to data.ibm_is_vpc.vpc.default_security_group.
  # If list is empty it will fail on reapply as when vsi is passed an empty security group list it will attach the default security group.
  allow_ip_spoofing = var.secondary_allow_ip_spoofing
  security_groups = length(flatten([
    (var.create_security_group && var.secondary_use_vsi_security_group ? [ibm_is_security_group.security_group[var.security_group.name].id] : []),
    [
      for group in var.secondary_security_groups :
      group.security_group_id if group.interface_name == each.value.name
    ]
    ])) == 0 ? [data.ibm_is_vpc.vpc.default_security_group] : flatten([
    (var.create_security_group && var.secondary_use_vsi_security_group ? [ibm_is_security_group.security_group[var.security_group.name].id] : []),
    [
      for group in var.secondary_security_groups :
      group.security_group_id if group.interface_name == each.value.name
    ]
  ])
  auto_delete               = false
  enable_infrastructure_nat = true
  dynamic "primary_ip" {
    for_each = var.manage_reserved_ips ? [1] : []
    content {
      reserved_ip = ibm_is_subnet_reserved_ip.secondary_vni_ip[each.key].reserved_ip
    }
  }
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

resource "ibm_is_subnet_reserved_ip" "vsi_ip" {
  for_each    = { for vsi_key, vsi_value in local.vsi_map : vsi_key => vsi_value if var.manage_reserved_ips }
  name        = "${each.value.name}-ip"
  subnet      = each.value.subnet_id
  auto_delete = false
}

resource "ibm_is_subnet_reserved_ip" "secondary_vsi_ip" {
  for_each    = { for key, value in local.secondary_reserved_ips_map : key => value if var.primary_vni_additional_ip_count > 0 && !var.use_legacy_network_interface }
  name        = "${each.value.name}-ip"
  subnet      = each.value.subnet_id
  auto_delete = false
}

resource "ibm_is_subnet_reserved_ip" "secondary_vni_ip" {
  for_each    = { for k in var.secondary_subnets : k.zone => k if !var.use_legacy_network_interface && var.manage_reserved_ips }
  name        = "${each.value.name}-ip"
  subnet      = each.value.id
  auto_delete = false
}

resource "ibm_is_instance" "vsi" {
  for_each        = local.vsi_map
  name            = each.value.vsi_name
  image           = (local.vsi_boot_volume_snapshot_id == null) ? var.image_id : null # image and snapshot are mutually exclusive
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

  # Primary Virtual Network Interface
  dynamic "primary_network_attachment" {
    for_each = var.use_legacy_network_interface ? [] : [1]
    content {
      name = ibm_is_virtual_network_interface.primary_vni[each.key].name
      virtual_network_interface {
        id = ibm_is_virtual_network_interface.primary_vni[each.key].id
      }
    }
  }

  # Additional Virtual Network Interface
  dynamic "network_attachments" {
    for_each = { for key, value in ibm_is_virtual_network_interface.secondary_vni : key => value if key == each.value.zone && !var.use_legacy_network_interface }
    content {
      name = network_attachments.value.name
      virtual_network_interface {
        id = network_attachments.value.id
      }
    }
  }

  # Legacy Network Interface
  dynamic "primary_network_interface" {
    for_each = var.use_legacy_network_interface ? [1] : []
    content {
      subnet = each.value.subnet_id
      security_groups = flatten([
        (var.create_security_group ? [ibm_is_security_group.security_group[var.security_group.name].id] : []),
        var.security_group_ids,
        (var.create_security_group == false && length(var.security_group_ids) == 0 ? [data.ibm_is_vpc.vpc.default_security_group] : []),
      ])
      allow_ip_spoofing = var.allow_ip_spoofing
      dynamic "primary_ip" {
        for_each = var.manage_reserved_ips ? [1] : []
        content {
          reserved_ip = ibm_is_subnet_reserved_ip.vsi_ip[each.value.name].reserved_ip
        }
      }
    }
  }
  # Legacy additional Network Interface
  dynamic "network_interfaces" {
    for_each = {
      for k in var.secondary_subnets : k.zone => k
      if k.zone == each.value.zone && var.use_legacy_network_interface
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
    name       = var.use_static_boot_volume_name ? "${each.value.vsi_name}-boot" : null
    # determine snapshot in following order: input variable -> from consistency group -> null (none)
    snapshot = local.vsi_boot_volume_snapshot_id
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
  target         = var.use_legacy_network_interface ? each.value.primary_network_interface[0].id : each.value.primary_network_attachment[0].virtual_network_interface[0].id
  tags           = var.tags
  access_tags    = var.access_tags
  resource_group = var.resource_group_id
}

resource "ibm_is_floating_ip" "secondary_fip" {
  for_each = var.use_legacy_network_interface ? length(var.secondary_floating_ips) == 0 ? {} : {
    for interface in local.legacy_secondary_fip_list :
    (interface.name) => interface
  } : {}
  name           = each.key
  target         = each.value.target
  tags           = var.tags
  access_tags    = var.access_tags
  resource_group = var.resource_group_id
}

resource "ibm_is_floating_ip" "vni_secondary_fip" {
  for_each       = local.secondary_fip_map
  name           = each.key
  target         = each.value.vni_id
  tags           = var.tags
  access_tags    = var.access_tags
  resource_group = var.resource_group_id
}
##############################################################################
