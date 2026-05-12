##############################################################################
# ibm_is_security_group
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

  # input variable validation
  # tflint-ignore: terraform_unused_declarations
  validate_security_group = var.create_security_group == false && var.security_group != null ? tobool("var.security_group should be null when var.create_security_group is false. Use var.security_group_ids to add security groups to VSI deployment primary interface.") : true
  # tflint-ignore: terraform_unused_declarations
  validate_security_group_2 = var.create_security_group == true && var.security_group == null ? tobool("var.security_group cannot be null when var.create_security_group is true.") : true
}

resource "ibm_is_security_group" "security_group" {
  for_each       = local.security_group_map
  name           = each.value.name
  resource_group = var.resource_group_id
  vpc            = var.vpc_id
  tags           = var.tags
  access_tags    = var.access_tags
}

##############################################################################


##############################################################################
# Change Security Group (Optional)
##############################################################################

locals {
  # Create list of all sg rules to create adding the name
  security_group_rule_list = flatten([
    for group in local.security_groups :
    [
      for rule in group.rules :
      merge({
        sg_name = group.name
      }, rule)
    ]
  ])

  # Convert list to map
  security_group_rules = {
    for rule in local.security_group_rule_list :
    ("${rule.sg_name}-${rule.name}") => rule
  }
}

resource "ibm_is_security_group_rule" "security_group_rules" {
  for_each   = local.security_group_rules
  group      = ibm_is_security_group.security_group[each.value.sg_name].id
  direction  = each.value.direction
  remote     = each.value.source
  local      = each.value.local
  ip_version = each.value.ip_version
  protocol   = each.value.protocol
  port_min   = each.value.port_min
  port_max   = each.value.port_max
  type       = each.value.type
  code       = each.value.code
}

##############################################################################
