##############################################################################
# Account Variables
##############################################################################

variable "resource_group_id" {
  description = "ID of resource group to create VSI and block storage volumes. If you wish to create the block storage volumes in a different resource group, you can optionally set that directly in the 'block_storage_volumes' variable."
  type        = string
}

variable "prefix" {
  description = "The prefix that you would like to append to your resources"
  type        = string
}

variable "tags" {
  description = "List of tags to apply to resources created by this module."
  type        = list(string)
  default     = []
}

##############################################################################


##############################################################################
# VPC Variables
##############################################################################

variable "vpc_id" {
  description = "ID of VPC"
  type        = string
}

variable "subnets" {
  description = "A list of subnet IDs where VSI will be deployed"
  type = list(
    object({
      name = string
      id   = string
      zone = string
      cidr = string
    })
  )
}

##############################################################################


##############################################################################
# VSI Variables
##############################################################################

variable "image_id" {
  description = "Image ID used for VSI. Run 'ibmcloud is images' to find available images in a region"
  type        = string
}

variable "ssh_key_ids" {
  description = "ssh key ids to use in creating vsi"
  type        = list(string)
}

variable "machine_type" {
  description = "VSI machine type. Run 'ibmcloud is instance-profiles' to get a list of regional profiles"
  type        = string
}

variable "vsi_per_subnet" {
  description = "Number of VSI instances for each subnet"
  type        = number
}

variable "user_data" {
  description = "User data to initialize VSI deployment"
  type        = string
}

variable "boot_volume_encryption_key" {
  description = "CRN of boot volume encryption key"
  type        = string
}

variable "use_boot_volume_key_as_default" {
  description = "Set to true to use the key specified in the `boot_volume_encryption_key` input as default for all volumes, overriding any key value that may be specified in the `encryption_key` option of the `block_storage_volumes` input variable. If set to `false`,  the value passed for the `encryption_key` option of the `block_storage_volumes` will be used instead."
  type        = bool
  default     = false
}

variable "manage_reserved_ips" {
  description = "Set to `true` if you want this terraform module to manage the reserved IP addresses that are assigned to VSI instances. If this option is enabled, when any VSI is recreated it should retain its original IP."
  type        = bool
  default     = false
}

variable "use_static_boot_volume_name" {
  description = "Sets the boot volume name for each VSI to a static name in the format `{hostname}_boot`, instead of a random name. Set this to `true` to have a consistent boot volume name even when VSIs are recreated."
  type        = bool
  default     = false
}

variable "enable_floating_ip" {
  description = "Create a floating IP for each virtual server created"
  type        = bool
  default     = false
}

variable "allow_ip_spoofing" {
  description = "Allow IP spoofing on the primary network interface"
  type        = bool
  default     = false
}

variable "create_security_group" {
  description = "Create security group for VSI. If this is passed as false, the default will be used"
  type        = bool
}

variable "security_group" {
  description = "Security group created for VSI"
  type = object({
    name = string
    rules = list(
      object({
        name      = string
        direction = string
        source    = string
        tcp = optional(
          object({
            port_max = number
            port_min = number
          })
        )
        udp = optional(
          object({
            port_max = number
            port_min = number
          })
        )
        icmp = optional(
          object({
            type = number
            code = number
          })
        )
      })
    )
  })
}

variable "security_group_ids" {
  description = "IDs of additional security groups to be added to VSI deployment primary interface. A VSI interface can have a maximum of 5 security groups."
  type        = list(string)
  default     = []
}

variable "block_storage_volumes" {
  description = "List describing the block storage volumes that will be attached to each vsi"
  type = list(
    object({
      name           = string
      profile        = string
      capacity       = optional(number)
      iops           = optional(number)
      encryption_key = optional(string)
      snapshot_id    = optional(string) # set if you would like to base volume on a snapshot
      tags           = optional(list(string), [])
    })
  )
  default = []
}

variable "load_balancers" {
  description = "Load balancers to add to VSI"
  type = list(
    object({
      name                    = string
      type                    = string
      listener_port           = number
      listener_protocol       = string
      connection_limit        = number
      idle_connection_timeout = optional(number)
      algorithm               = string
      protocol                = string
      health_delay            = number
      health_retries          = number
      health_timeout          = number
      health_type             = string
      pool_member_port        = string
      profile                 = optional(string)
      dns = optional(
        object({
          instance_crn = string
          zone_id      = string
        })
      )
      security_group = optional(
        object({
          name = string
          rules = list(
            object({
              name      = string
              direction = string
              source    = string
              tcp = optional(
                object({
                  port_max = number
                  port_min = number
                })
              )
              udp = optional(
                object({
                  port_max = number
                  port_min = number
                })
              )
              icmp = optional(
                object({
                  type = number
                  code = number
                })
              )
            })
          )
        })
      )
    })
  )
  default = []
}

variable "existing_kms_instance_guid" {
  description = "The GUID of the Hyper Protect Crypto Services or Key Protect instance in which the key specified in var.kms_key_crn and var.backup_encryption_key_crn is coming from. Required only if var.skip_iam_authorization_policy is set to false."
  type        = string
  default     = null
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Set to true to skip the creation of an IAM authorization policy that permits all Storage Blocks to read the encryption key from the KMS instance. If set to false, pass in a value for the KMS instance in the existing_kms_instance_guid variable."
  default     = false
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the VSI resources created by the module. For more information, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial."
  default     = []
}

variable "custom_vsi_volume_names" {
  description = "A map of subnets, VSI names, and storage volume names. Subnet names should correspond to existing subnets, while VSI and storage volume names are used for resource creation. Format example: { 'subnet_name_1': { 'vsi_name_1': [ 'storage_volume_name_1', 'storage_volume_name_2' ] } }"
  type        = map(map(list(string)))
  default     = {}
  nullable    = false

  # Validation to ensure the map has the same number of volumes as the number of block storage volumes defiend in 'block_storage_volumes'
  validation {
    condition = alltrue([
      for subnet_key, subnet_value in coalesce(var.custom_vsi_volume_names, {}) : alltrue([
        for vsi_key, volumes in subnet_value : length(volumes) == length(var.block_storage_volumes)
      ])
    ])
    error_message = "The number of storage volume names must be the same as the number of block storage volumes defined in 'block_storage_volumes' input variable."
  }

  # Validation to ensure that volume names are unique
  validation {
    condition = alltrue([
      for subnet, vsi_map in var.custom_vsi_volume_names :
      alltrue([
        for vsi_name, volumes in vsi_map :
        length(volumes) == length(distinct(volumes))
      ])
    ])
    error_message = "Each member of a list of storage volume names for a vsi_name must be unique."
  }

  # Validation to ensure that number of subnets is not higher than the number of subnets defined in var.subnets
  validation {
    condition     = length(keys(var.custom_vsi_volume_names)) <= length(var.subnets)
    error_message = "The number of subnets defined in the custom_vsi_volume_names input variable should not exceed the number of subnets defined in the subnets input variable."
  }

  # Validation to ensure that number of VSIs is not higher then the number defined in vsi_per_subnet
  validation {
    condition     = length(var.custom_vsi_volume_names) > 0 ? sort([for subnet, vsis in var.custom_vsi_volume_names : length(keys(vsis))])[length([for subnet, vsis in var.custom_vsi_volume_names : length(keys(vsis))]) - 1] <= var.vsi_per_subnet : true
    error_message = "The number of VSIs defined in the custom_vsi_volume_names input variable should not exceed the number specified in the vsi_per_subnet input variable."
  }

  # Validation to ensure the VSI names are unique across different subnets
  validation {
    condition = length(distinct(flatten([
      for subnet, vsi_map in var.custom_vsi_volume_names : [
        for vsi_name, _ in vsi_map : vsi_name
      ]
      ]))) == length(flatten([
      for subnet, vsi_map in var.custom_vsi_volume_names : [
        for vsi_name, _ in vsi_map : vsi_name
      ]
    ]))
    error_message = "VSI names must be unique across all subnets."
  }
}

##############################################################################
# Snapshot Restore Variables
##############################################################################

variable "boot_volume_snapshot_id" {
  description = "The snapshot id of the volume to be used for creating boot volume attachment (if specified, the `image_id` parameter will not be used)"
  type        = string
  default     = null
}

variable "snapshot_consistency_group_id" {
  description = "The snapshot consistency group Id. If supplied, the group will be queried for snapshots that are matched with both boot volume and attached (attached are matched based on name suffix). You can override specific snapshot Ids by setting the appropriate input variables as well."
  type        = string
  default     = null
}

##############################################################################

##############################################################################
# Dedicated Host Variables
##############################################################################

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  nullable    = false
  description = "Enabling this option will activate dedicated hosts for the VSIs. When enabled, the dedicated_host_id input is required. The default value is set to false. Refer [Understanding Dedicated Hosts](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-dedicated-hosts-instances&interface=ui#about-dedicated-hosts) for more details"
}

variable "dedicated_host_id" {
  type        = string
  default     = null
  description = "ID of the dedicated host for hosting the VSI's. The enable_dedicated_host input shoud be set to true if passing a dedicated host ID"
}

##############################################################################
