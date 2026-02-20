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

locals {
  # True when tcp block has at least one non-null port value
  sg_rule_has_tcp = {
    for k, v in local.security_group_rules : k => (
      v.tcp != null &&
      length([for x in ["port_min", "port_max"] : true if lookup(v["tcp"], x, null) != null]) > 0
    )
  }

  # True when udp block has at least one non-null port value
  sg_rule_has_udp = {
    for k, v in local.security_group_rules : k => (
      v.udp != null &&
      length([for x in ["port_min", "port_max"] : true if lookup(v["udp"], x, null) != null]) > 0
    )
  }

  # True when icmp block has at least one non-null type/code value
  sg_rule_has_icmp = {
    for k, v in local.security_group_rules : k => (
      v.icmp != null &&
      length([for x in ["type", "code"] : true if lookup(v["icmp"], x, null) != null]) > 0
    )
  }
}

resource "ibm_is_security_group_rule" "security_group_rules" {
  for_each   = local.security_group_rules
  group      = ibm_is_security_group.security_group[each.value.sg_name].id
  direction  = each.value.direction
  remote     = each.value.source
  local      = each.value.local
  ip_version = each.value.ip_version


  # Deprecated nested protocol blocks (tcp/udp/icmp) replaced by top-level fields
  protocol = (
    local.sg_rule_has_tcp[each.key] ? "tcp" :
    local.sg_rule_has_udp[each.key] ? "udp" :
    local.sg_rule_has_icmp[each.key] ? "icmp" :
    null
  )

  port_min = (
    local.sg_rule_has_tcp[each.key] ? lookup(each.value["tcp"], "port_min", null) :
    local.sg_rule_has_udp[each.key] ? lookup(each.value["udp"], "port_min", null) :
    null
  )

  port_max = (
    local.sg_rule_has_tcp[each.key] ? lookup(each.value["tcp"], "port_max", null) :
    local.sg_rule_has_udp[each.key] ? lookup(each.value["udp"], "port_max", null) :
    null
  )

  type = local.sg_rule_has_icmp[each.key] ? lookup(each.value["icmp"], "type", null) : null
  code = local.sg_rule_has_icmp[each.key] ? lookup(each.value["icmp"], "code", null) : null

}

##############################################################################
