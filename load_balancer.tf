##############################################################################
# Load Balancer
##############################################################################

locals {
  load_balancer_map = {
    for load_balancer in var.load_balancers :
    (load_balancer.name) => load_balancer
  }

  subnets_id = var.subnets[*].id
}

resource "ibm_is_lb" "lb" {
  for_each        = local.load_balancer_map
  name            = "${var.prefix}-${each.value.name}-lb"
  subnets         = (each.value.profile == "network-fixed") ? [local.subnets_id[0]] : local.subnets_id
  type            = each.value.type #checkov:skip=CKV2_IBM_1:See https://github.com/bridgecrewio/checkov/issues/5824#
  profile         = each.value.profile
  security_groups = each.value.security_group == null ? null : [ibm_is_security_group.security_group[each.value.security_group.name].id]
  resource_group  = var.resource_group_id
  tags            = var.tags
  access_tags     = var.access_tags

  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}

##############################################################################


##############################################################################
# Load Balancer Pool
##############################################################################

resource "ibm_is_lb_pool" "pool" {
  for_each       = local.load_balancer_map
  lb             = ibm_is_lb.lb[each.value.name].id
  name           = "${var.prefix}-${each.value.name}-lb-pool"
  algorithm      = each.value.algorithm
  protocol       = each.value.protocol
  health_delay   = each.value.health_delay
  health_retries = each.value.health_retries
  health_timeout = each.value.health_timeout
  health_type    = each.value.health_type
}

##############################################################################

##############################################################################
# Load Balancer Pool Member
##############################################################################

locals {
  alb_pool_members = flatten([
    for load_balancer in var.load_balancers :
    [
      for ipv4_address in [
        for server in ibm_is_instance.vsi :
        lookup(server, "primary_network_interface", null) == null ? null : server.primary_network_interface[0].primary_ipv4_address
      ] :
      {
        port           = load_balancer.pool_member_port
        target_address = ipv4_address
        lb             = load_balancer.name
        profile        = load_balancer.profile
      } if(load_balancer.profile != "network-fixed")
    ]
  ])

  nlb_pool_members = flatten([
    for load_balancer in var.load_balancers :
    [
      for server in ibm_is_instance.vsi :
      {
        port      = load_balancer.pool_member_port
        lb        = load_balancer.name
        target_id = server.id
        profile   = load_balancer.profile
      } if(load_balancer.profile == "network-fixed")
    ]
  ])
}

resource "ibm_is_lb_pool_member" "alb_pool_members" {
  count          = length(local.alb_pool_members)
  port           = local.alb_pool_members[count.index].port
  lb             = ibm_is_lb.lb[local.alb_pool_members[count.index].lb].id
  pool           = element(split("/", ibm_is_lb_pool.pool[local.alb_pool_members[count.index].lb].id), 1)
  target_address = local.alb_pool_members[count.index].target_address
}

resource "ibm_is_lb_pool_member" "nlb_pool_members" {
  count     = length(local.nlb_pool_members)
  port      = local.nlb_pool_members[count.index].port
  lb        = ibm_is_lb.lb[local.nlb_pool_members[count.index].lb].id
  pool      = element(split("/", ibm_is_lb_pool.pool[local.nlb_pool_members[count.index].lb].id), 1)
  target_id = local.nlb_pool_members[count.index].target_id
}

##############################################################################



##############################################################################
# Load Balancer Listener
##############################################################################

resource "ibm_is_lb_listener" "listener" {
  for_each                = local.load_balancer_map
  lb                      = ibm_is_lb.lb[each.value.name].id
  default_pool            = ibm_is_lb_pool.pool[each.value.name].id
  port                    = each.value.listener_port
  port_min                = (each.value.listener_port == null && each.value.profile == "network-fixed") ? each.value.listener_port_min : null
  port_max                = (each.value.listener_port == null && each.value.profile == "network-fixed") ? each.value.listener_port_max : null
  protocol                = each.value.listener_protocol
  connection_limit        = each.value.profile != "network-fixed" ? (each.value.connection_limit > 0 ? each.value.connection_limit : null) : null
  idle_connection_timeout = each.value.profile != "network-fixed" ? each.value.idle_connection_timeout : null
  accept_proxy_protocol   = each.value.accept_proxy_protocol
  depends_on              = [ibm_is_lb_pool_member.alb_pool_members, ibm_is_lb_pool_member.nlb_pool_members]
}

##############################################################################
