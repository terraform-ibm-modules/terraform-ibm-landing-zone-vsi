##############################################################################
# Snapshot Consistency Group
#
# If a consistency group id is supplied, determine volume snapshots to use
# by looking at details/service_tags of the snapshots that belong to the group,
# and map those snapshots to their appropriate volumes.
#
# NOTE: any snapshot_id that is specifically set in any input variables will
#       take precedence over the consistency group snapshots
##############################################################################

data "ibm_is_snapshot_consistency_group" "snapshot_group" {
  count      = var.snapshot_consistency_group_id != null ? 1 : 0
  identifier = var.snapshot_consistency_group_id
}

data "ibm_is_snapshot" "snapshots_from_group" {
  for_each   = local.consistency_group_available_snapshots_map
  identifier = each.value.id
}

locals {
  # this map with snapshot names as keys is only used to get snapshot details from data block (consistency_group snapshots element does not contain all detail)
  consistency_group_available_snapshots_map = length(data.ibm_is_snapshot_consistency_group.snapshot_group) > 0 ? { for snap in data.ibm_is_snapshot_consistency_group.snapshot_group[0].snapshots : snap.name => snap } : {}

  # find the bootable snapshot by service tag, looking always for index 0, if it doesn't exist then no snapshot for boot volume (null)
  consistency_group_boot_snapshots   = [for snap in data.ibm_is_snapshot.snapshots_from_group : snap if contains(snap.tags, "is.snapshot:attachment_index_0") && snap.bootable]
  consistency_group_boot_snapshot_id = one(local.consistency_group_boot_snapshots[*].identifier)

  # loop through desired additional block volumes, and see if snapshot in group exists by looking at service tag and index, starting at _1
  consistency_group_snapshot_to_volume_map = {
    for idx, volume in var.block_storage_volumes :
    volume.name => one([for snap in data.ibm_is_snapshot.snapshots_from_group : snap.identifier if contains(snap.tags, format("%s%s", "is.snapshot:attachment_index_", tostring(idx + 1)))])
  }
}
