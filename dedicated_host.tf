##############################################################################
# Creating dedicated host for VSI's
##############################################################################

module "dedicated_host" {
  source            = "terraform-ibm-modules/dedicated-host/ibm"
  version           = "1.0.0"

  for_each = var.enable_dedicated_host ? {
    for zone in distinct([for vsi_key, vsi_value in local.vsi_map : trimspace(lower(vsi_value.zone))]) :
    zone => {
      name  = "${var.prefix}-${zone}-dh"
      zone  = zone
      class = var.dh_profile_class
      family = var.dh_profile_family
      resource_group_id = var.resource_group_id
    }
  } : {}

  name              = each.value.name
  zone              = each.key
  resource_group_id = each.value.resource_group_id
  class             = each.value.class
  family            = each.value.family
}

##############################################################################