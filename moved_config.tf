############################################################################################################################################
# The following moved blocks allow consumers to upgrade the module from v3.2.4 or older without destroying the existing ALB pool members
# For more details, please refer - https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/issues/649
############################################################################################################################################

moved {
  from = ibm_is_lb_pool_member.pool_members
  to   = ibm_is_lb_pool_member.alb_pool_members
}
