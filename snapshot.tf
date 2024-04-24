data "ibm_is_snapshot_consistency_group" "snapshot_group" {
  count      = var.snapshot_consistency_group_id != null ? 1 : 0
  identifier = var.snapshot_consistency_group_id
}

data "ibm_is_snapshot" "snapshots_from_group" {
  for_each   = local.consistency_group_available_snapshots_map
  identifier = each.value.id
}

locals {
  consistency_group_available_snapshots_map = length(data.ibm_is_snapshot_consistency_group.snapshot_group) > 0 ? { for snap in data.ibm_is_snapshot_consistency_group.snapshot_group[0].snapshots : snap.name => snap } : {}
  # find the bootable snapshot
  consistency_group_boot_snapshots       = [for snap in data.ibm_is_snapshot.snapshots_from_group : snap if snap.bootable]
  consistency_group_nonboot_snapshots    = [for snap in data.ibm_is_snapshot.snapshots_from_group : snap if !snap.bootable]
  consistency_group_boot_snapshot_id     = length(local.consistency_group_boot_snapshots) > 0 ? local.consistency_group_boot_snapshots[0].identifier : null
  consistency_group_storage_snapshot_ids = [for snap in local.consistency_group_nonboot_snapshots : snap.identifier]

  # if storage snapshots exist, map them to required volumes in sort order (maps are sorted alpha by keys automatically)
  consistency_group_snapshot_to_volume_map = {
    for idx, volume in var.block_storage_volumes :
    volume.name => length(local.consistency_group_storage_snapshot_ids) >= idx + 1 ? local.consistency_group_storage_snapshot_ids[idx] : null
  }
}
