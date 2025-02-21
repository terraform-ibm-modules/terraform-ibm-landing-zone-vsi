##############################################################################
# Create Volumes
##############################################################################
locals {

  # set required data for block storage volumes, which are used for volume_list creation
  volumes = [for volume in var.block_storage_volumes :
    {
      vol_name_ref   = volume.name
      profile        = volume.profile
      capacity       = (volume.snapshot_id == null) ? volume.capacity : null
      iops           = (volume.snapshot_id == null) ? volume.iops : null
      encryption_key = (volume.snapshot_id == null) ? (var.use_boot_volume_key_as_default ? var.boot_volume_encryption_key : (var.kms_encryption_enabled ? volume.encryption_key : null)) : null
      resource_group = volume.resource_group_id != null ? volume.resource_group_id : var.resource_group_id
      tags           = volume.tags
      # check for snapshot in this order: supplied directly in variable -> part of consistency group -> null (no snapshot)
      snapshot_id = try(coalesce(volume.snapshot_id, lookup(local.consistency_group_snapshot_to_volume_map, volume.name, null)), null)
  }]


  ##############################################################################
  # Create a temp list of volumes for each VSI using subnets and VSI per subnet
  ##############################################################################
  volume_list_dynamic_temp = flatten([
    # For each subnet
    for subnet in range(length(var.subnets)) : [
      # For each number in a range from 0 to VSI per subnet
      for count in range(var.vsi_per_subnet) : [
        # For each volume
        for idx, key in(var.block_storage_volumes) : merge(
          {
            name     = "${var.subnets[subnet].name}-${count}-${var.block_storage_volumes[idx].name}"
            vol_name = "${var.prefix}-${substr(var.subnets[subnet].id, -4, 4)}-${format("%03d", count + 1)}-${var.block_storage_volumes[idx].name}"
            zone     = var.subnets[subnet].zone
            vsi_name = "${var.subnets[subnet].name}-${count}"
          },
          local.volumes[idx]
        )
      ]
    ]
  ])

  # need to remove 'vol_name_ref' (temp value) which was added to 'local.volumes' to have a value that is a part of 'name'
  volume_list_dynamic = [
    for m in local.volume_list_dynamic_temp : {
      for k, v in m : k => v if k != "vol_name_ref"
    }
  ]

  ##############################################################################

  ##############################################################################
  # Create a list of volumes for each VSI using 'custom_vsi_volume_names' input variable
  ##############################################################################
  volume_list_static_temp = flatten([
    for idx, vsi in local.vsi_list_static : [
      for index, storage_volume in lookup(var.custom_vsi_volume_names[vsi.subnet_name], vsi.vsi_name, []) : merge(
        {
          name     = "${vsi.name}-${local.volumes[index].vol_name_ref}"
          vsi_name = vsi.name
          zone     = vsi.zone
          vol_name = storage_volume
        },
        local.volumes[index]
      )
    ]
  ])

  # need to remove 'vol_name_ref' (temp value) which was added to 'local.volumes' to have a value that is a part of 'name'
  volume_list_static = [
    for m in local.volume_list_static_temp : {
      for k, v in m : k => v if k != "vol_name_ref"
    }
  ]
  ##############################################################################

  # vsi list can be created dynamically or statically (using 'custom_vsi_volume_names' input variable)
  volume_list = var.custom_vsi_volume_names != null && length(keys(var.custom_vsi_volume_names)) > 0 ? local.volume_list_static : local.volume_list_dynamic

  # Map of all volumes
  volume_map = {
    for volume in local.volume_list :
    volume.name => volume
  }
}


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
