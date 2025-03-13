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
        for idx, volume in(var.block_storage_volumes) :
        {
          name = "${var.subnets[subnet].name}-${count}-${volume.name}"
          # try to lookup for a volume name inside custom_vsi_volume_names input variable for that specific subnet, if not found then dynamic volume name is used
          vol_name       = try(values(lookup(var.custom_vsi_volume_names, var.subnets[subnet].name, {}))[count][idx], "${var.prefix}-${substr(var.subnets[subnet].id, -4, 4)}-${format("%03d", count + 1)}-${volume.name}")
          zone           = var.subnets[subnet].zone
          profile        = volume.profile
          capacity       = (volume.snapshot_id == null) ? volume.capacity : null
          vsi_name       = "${var.subnets[subnet].name}-${count}"
          iops           = (volume.snapshot_id == null) ? volume.iops : null
          encryption_key = (volume.snapshot_id == null) ? (var.use_boot_volume_key_as_default ? var.boot_volume_encryption_key : (var.kms_encryption_enabled ? volume.encryption_key : null)) : null
          resource_group = volume.resource_group_id != null ? volume.resource_group_id : var.resource_group_id
          # check for snapshot in this order: supplied directly in variable -> part of consistency group -> null (no snapshot)
          snapshot_id = try(coalesce(volume.snapshot_id, lookup(local.consistency_group_snapshot_to_volume_map, volume.name, null)), null)
          tags        = volume.tags
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
  for_each        = local.volume_map
  name            = each.value.vol_name
  profile         = each.value.profile
  zone            = each.value.zone
  iops            = each.value.iops
  capacity        = each.value.capacity
  encryption_key  = each.value.encryption_key
  resource_group  = each.value.resource_group
  tags            = var.tags != null ? distinct(concat(var.tags, each.value.tags)) : null
  access_tags     = var.access_tags
  source_snapshot = each.value.snapshot_id
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
