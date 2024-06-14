module "fscloud_vsi" {
  source                        = "../../"
  resource_group_id             = var.resource_group_id
  prefix                        = var.prefix
  tags                          = var.tags
  vpc_id                        = var.vpc_id
  subnets                       = var.subnets
  image_id                      = var.image_id
  ssh_key_ids                   = var.ssh_key_ids
  machine_type                  = var.machine_type
  vsi_per_subnet                = var.vsi_per_subnet
  user_data                     = var.user_data
  existing_kms_instance_guid    = var.existing_kms_instance_guid
  skip_iam_authorization_policy = var.skip_iam_authorization_policy
  boot_volume_encryption_key    = var.boot_volume_encryption_key
  kms_encryption_enabled        = true
  manage_reserved_ips           = var.manage_reserved_ips
  enable_floating_ip            = var.enable_floating_ip
  allow_ip_spoofing             = var.allow_ip_spoofing
  create_security_group         = var.create_security_group
  security_group                = var.security_group
  security_group_ids            = var.security_group_ids
  block_storage_volumes         = var.block_storage_volumes
  load_balancers                = var.load_balancers
  access_tags                   = var.access_tags
  snapshot_consistency_group_id = var.snapshot_consistency_group_id
  boot_volume_snapshot_id       = var.boot_volume_snapshot_id
}
