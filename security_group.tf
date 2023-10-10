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

  # input variable validation
  # tflint-ignore: terraform_unused_declarations
  validate_security_group = var.create_security_group == false && var.security_group != null ? tobool("var.security_group should be null when var.create_security_group is false. Use var.security_group_ids to add security groups to VSI deployment primary interface.") : true
  # tflint-ignore: terraform_unused_declarations
  validate_security_group_2 = var.create_security_group == true && var.security_group == null ? tobool("var.security_group cannot be null when var.create_security_group is true.") : true

  # Change the "source" key in the rules map to "remote"
  # This change was introduced in the 2.0.0 version of the security group module
  # In order to prevent changes to the input variables we replace the key name here.
  source_to_remote_map = {
    for name, obj in local.security_group_map :
    name => merge({
      for k, v in obj :
      k => v if k != "rules"
      },
      {
        rules = [
          for rule in obj.rules : {
            for k, v in rule : replace(k, "/source/", "remote") => v
          }
        ]
    })
  }
}

module "security_groups" {
  for_each                     = local.source_to_remote_map
  source                       = "git::https://github.com/terraform-ibm-modules/terraform-ibm-security-group.git?ref=v2.0.0"
  add_ibm_cloud_internal_rules = each.value.add_ibm_cloud_internal_rules
  security_group_name          = each.key
  security_group_rules         = each.value.rules
  resource_group               = var.resource_group_id
  vpc_id                       = var.vpc_id
}

##############################################################################
