module "resource_group" {
  count                        = var.create_vpc ? 1 : 0
  source                       = "terraform-ibm-modules/resource-group/ibm"
  version                      = "1.4.7"
  resource_group_name          = var.resource_group == null ? "${var.prefix}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

#############################################################################
# Provision VPC
#############################################################################

module "vpc" {
  count             = var.create_vpc ? 1 : 0
  source            = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version           = "8.12.5"
  resource_group_id = module.resource_group[0].resource_group_id
  region            = var.region
  name              = "vpc"
  prefix            = var.prefix
  tags              = var.resource_tags
  subnets = {
    zone-1 = [
      {
        name           = "subnet-a"
        cidr           = "10.10.10.0/24"
        public_gateway = true
        acl_name       = "vpc-acl"
      }
    ]
  }
}

module "vsi_image_selector" {
  source           = "terraform-ibm-modules/common-utilities/ibm//modules/vsi-image-selector"
  version          = "1.4.1"
  architecture     = "amd64"
  operating_system = "ubuntu"
}
