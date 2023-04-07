##############################################################################
# Create Security Group optionally and Security Group Rules adding IBM Cloud Internal rules optionally
##############################################################################

locals {
  vsi_security_group = [var.create_security_group ? var.security_group : null]
  # Create list of all security groups including the ones for load balancers
  security_groups = flatten([
    [
      for group in local.vsi_security_group :
      group if group != null
    ],
    [
      for load_balancer in var.load_balancers :
      load_balancer.security_group if load_balancer.security_group != null
    ]
  ])

  # Convert list to map
  security_group_map = {
    for group in local.security_groups :
    (group.name) => group
  }
}




module "security_group_rules" {
  for_each                     = local.security_group_map
  source                       = "git::https://github.com/terraform-ibm-modules/terraform-ibm-security-group.git?ref=v1.0.0"
  add_ibm_cloud_internal_rules = var.add_ibm_cloud_internal_rules
  security_group_name          = each.key
  security_group_rules         = each.value.rules
  resource_group               = var.resource_group_id
  vpc_id                       = var.vpc_id
}

##############################################################################
