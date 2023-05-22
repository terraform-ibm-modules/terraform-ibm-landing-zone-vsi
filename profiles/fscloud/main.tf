module "slz_vsi" {
  source                     = "../../"
  resource_group_id          = local.resource_group_id
  image_id                   = var.image_id
  create_security_group      = var.create_security_group
  security_group             = var.security_group
  tags                       = var.resource_tags
  subnets                    = module.slz_vpc.subnet_zone_list
  vpc_id                     = module.slz_vpc.vpc_id
  prefix                     = var.prefix
  machine_type               = var.machine_type
  user_data                  = var.user_data
  boot_volume_encryption_key = var.boot_volume_encryption_key
  vsi_per_subnet             = var.vsi_per_subnet
  ssh_key_ids                = [local.ssh_key_id]
}
