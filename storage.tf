##############################################################################
# Create Volumes
##############################################################################

locals {

  # List of volumes for each VSI
  volume_list = flatten([
    # For each subnet
    for subnet in range(length(var.subnets)) : [
      # For each number in a range from 0 to VSI per subnet
      for count in range(var.vsi_per_subnet) : [
        # For each volume
        for volume in var.block_storage_volumes :
        {
          name           = "${var.subnets[subnet].name}-${count}-${volume.name}"
          vol_name       = "${var.prefix}-${var.subnets[subnet].name}-${format("%03d", count)}-${volume.name}"
          zone           = var.subnets[subnet].zone
          profile        = volume.profile
          capacity       = volume.capacity
          vsi_name       = "${var.subnets[subnet].name}-${count}"
          iops           = volume.iops
          encryption_key = var.kms_encryption_enabled ? var.boot_volume_encryption_key : volume.encryption_key
          resource_group = volume.resource_group_id != null ? volume.resource_group_id : var.resource_group_id
        }
      ]
    ]
  ])

  # Map of all volumes
  volume_map = {
    for volume in local.volume_list :
    volume.name => volume
  }
}

##############################################################################

##############################################################################
# Create Volumes
##############################################################################

resource "ibm_is_volume" "volume" {
  for_each       = local.volume_map
  name           = each.value.vol_name
  profile        = each.value.profile
  zone           = each.value.zone
  iops           = each.value.iops
  capacity       = each.value.capacity
  encryption_key = each.value.encryption_key
  resource_group = each.value.resource_group
  tags           = var.tags
  access_tags    = var.access_tags
}

##############################################################################


##############################################################################
# Map Volumes to VSI Name
##############################################################################

locals {
  # Create a map that groups lists of volumes by VSI name to be referenced in
  # instance creation
  volume_by_vsi = {
    # For each distinct server name
    for virtual_server in distinct(local.volume_list[*].vsi_name) :
    # Create an object where the key is the name of the server
    (virtual_server) => [
      # That includes the ids of only volumes with the matching `vsi_name`
      for volume in local.volume_list :
      ibm_is_volume.volume[volume.name].id if volume.vsi_name == virtual_server
    ]
  }
}

##############################################################################
