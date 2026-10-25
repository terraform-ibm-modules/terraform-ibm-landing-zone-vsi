##############################################################################
# Virtual Server Instance Reinitialization
#
# Instance reinitialization is a destructive operation that permanently deletes
# the existing boot volume and creates a new one using the specified boot source
# (image, volume, or snapshot).
##############################################################################

locals {
  reinitialize_vsi_map = (var.reinitialize != null && try(var.reinitialize.enabled, true)) ? {
    for k, v in local.vsi_map : k => v
    if(
      var.reinitialize.vsi_names == null ||
      length(var.reinitialize.vsi_names) == 0 ||
      contains(var.reinitialize.vsi_names, v.vsi_name) ||
      contains(var.reinitialize.vsi_names, k)
    )
  } : {}
}

resource "ibm_is_instance_reinitialize" "reinitialize" {
  for_each   = local.reinitialize_vsi_map
  depends_on = [ibm_is_instance.vsi]

  instance_id = ibm_is_instance.vsi[each.key].id
  image       = var.reinitialize.image
  keys        = var.reinitialize.keys
  user_data   = var.reinitialize.user_data

  dynamic "boot_volume_attachment" {
    for_each = var.reinitialize.boot_volume_attachment != null ? [var.reinitialize.boot_volume_attachment] : []
    content {
      name                             = boot_volume_attachment.value.name
      delete_volume_on_instance_delete = boot_volume_attachment.value.delete_volume_on_instance_delete

      dynamic "volume" {
        for_each = boot_volume_attachment.value.volume != null ? [boot_volume_attachment.value.volume] : []
        content {
          id             = volume.value.id
          name           = volume.value.name
          capacity       = volume.value.capacity
          iops           = volume.value.iops
          bandwidth      = volume.value.bandwidth
          resource_group = volume.value.resource_group
          user_tags      = volume.value.user_tags

          dynamic "encryption_key" {
            for_each = volume.value.encryption_key != null ? [volume.value.encryption_key] : []
            content {
              crn = encryption_key.value.crn
            }
          }

          dynamic "profile" {
            for_each = volume.value.profile != null ? [volume.value.profile] : []
            content {
              name = profile.value.name
            }
          }

          dynamic "source_snapshot" {
            for_each = volume.value.source_snapshot != null ? [volume.value.source_snapshot] : []
            content {
              id = source_snapshot.value.id
            }
          }

          dynamic "allowed_use" {
            for_each = volume.value.allowed_use != null ? [volume.value.allowed_use] : []
            content {
              api_version       = allowed_use.value.api_version
              bare_metal_server = allowed_use.value.bare_metal_server
              instance          = allowed_use.value.instance
            }
          }
        }
      }
    }
  }

  dynamic "default_trusted_profile" {
    for_each = var.reinitialize.default_trusted_profile != null ? [var.reinitialize.default_trusted_profile] : []
    content {
      auto_link = default_trusted_profile.value.auto_link

      dynamic "target" {
        for_each = default_trusted_profile.value.target != null ? [default_trusted_profile.value.target] : []
        content {
          id  = target.value.id
          crn = target.value.crn
        }
      }
    }
  }
}
