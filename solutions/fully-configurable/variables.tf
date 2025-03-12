########################################################################################################################
# Input variables
########################################################################################################################

variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud api key"
  sensitive   = true
}

variable "prefix" {
  type        = string
  nullable    = false
  description = "The prefix to add to all resources that this solution creates (e.g `prod`, `test`, `dev`)."
  validation {
    error_message = "Prefix must begin and end with a letter and contain only letters, numbers, and - characters."
    condition     = can(regex("^([A-z]|[a-z][-a-z0-9]*[a-z0-9])$", var.prefix))
  }
}

variable "existing_resource_group_name" {
  type        = string
  description = "The name of an existing resource group to provision the VSIs."
}

variable "region" {
  type        = string
  description = "Region where resources are created"
}

variable "provider_visibility" {
  description = "Set the visibility value for the IBM terraform provider. Supported values are `public`, `private`, `public-and-private`. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/guides/custom-service-endpoints)."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private", "public-and-private"], var.provider_visibility)
    error_message = "Invalid visibility option. Allowed values are 'public', 'private', or 'public-and-private'."
  }
}

variable "resource_tags" {
  description = "List of tags to apply to resources created by this module."
  type        = list(string)
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the VSI resources created by the module. For more information, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial."
  default     = []
}

##############################################################################


##############################################################################
# VPC Variables
##############################################################################

variable "existing_vpc_id" {
  description = "The ID of an existing VPC."
  type        = string
}

variable "existing_subnet_id" {
  description = "The ID of an existing subnet"
  type        = string
}

##############################################################################


##############################################################################
# VSI Variables
##############################################################################

variable "vsi_name" {
  description = ""
  type        = string
  default     = "vsi"
}

variable "image_id" {
  description = "Image ID used for VSI. Run 'ibmcloud is images' to find available images in a region"
  type        = string
  default     = "r006-cc341965-a523-464e-969f-391e2661c125"
}

variable "ssh_public_key" {
  description = "A public SSH Key for VSI creation which does not already exist in the deployment region. Must be an RSA key with a key size of either 2048 bits or 4096 bits (recommended) - See https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys. To use an existing key, enter a value for the variable 'existing_ssh_key_name' instead."
  type        = string
  default     = null
  validation {
    error_message = "Public SSH Key must be a valid ssh rsa public key."
    condition     = var.ssh_public_key == null || can(regex("ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3} ?([^@]+@[^@]+)?", var.ssh_public_key))
  }
  validation {
    condition     = var.ssh_public_key != null || length(var.existing_ssh_key_ids) > 0 ? true : false
    error_message = "Please provide a value for either `ssh_public_key` or `existing_ssh_key_ids`."
  }
}

variable "existing_ssh_key_ids" {
  description = "ssh key ids to use in creating vsi"
  type        = list(string)
  default     = []
}

variable "machine_type" {
  description = "VSI machine type. Run 'ibmcloud is instance-profiles' to get a list of regional profiles"
  type        = string
  default     = "cx2-2x4"
}

variable "user_data" {
  description = "User data to initialize VSI deployment"
  type        = string
  default     = null
}

variable "use_boot_volume_key_as_default" {
  description = "Set to true to use the key specified in the `boot_volume_encryption_key` input as default for all volumes, overriding any key value that may be specified in the `encryption_key` option of the `block_storage_volumes` input variable. If set to `false`,  the value passed for the `encryption_key` option of the `block_storage_volumes` will be used instead."
  type        = bool
  default     = false
}

variable "boot_volume_encryption_key" {
  description = "CRN of boot volume encryption key"
  default     = null
  type        = string
}

variable "existing_kms_instance_guid" {
  description = "The GUID of the Hyper Protect Crypto Services instance in which the key specified in var.boot_volume_encryption_key is coming from."
  type        = string
  default     = null
}

variable "manage_reserved_ips" {
  description = "Set to `true` if you want this terraform module to manage the reserved IP addresses that are assigned to VSI instances. If this option is enabled, when any VSI is recreated it should retain its original IP."
  type        = bool
  default     = false
}

variable "primary_vni_additional_ip_count" {
  description = "The number of secondary reversed IPs to attach to a Virtual Network Interface (VNI). Additional IPs are created only if `manage_reserved_ips` is set to true."
  type        = number
  nullable    = false
  default     = 0
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
  default     = false
}

variable "placement_group_id" {
  description = "Unique Identifier of the Placement Group for restricting the placement of the instance, default behaviour is placement on any host"
  type        = string
  default     = null
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
  default = null
}

variable "security_group_ids" {
  description = "IDs of additional security groups to be added to VSI deployment primary interface. A VSI interface can have a maximum of 5 security groups."
  type        = list(string)
  default     = []
}

variable "kms_encryption_enabled" {
  type        = bool
  description = "Set this to true to control the encryption keys used to encrypt the data that for the block storage volumes for VPC. If set to false, the data is encrypted by using randomly generated keys. For more info on encrypting block storage volumes, see https://cloud.ibm.com/docs/vpc?topic=vpc-creating-instances-byok"
  default     = false
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Set to true to skip the creation of an IAM authorization policy that permits all Storage Blocks to read the encryption key from the KMS instance. If set to false, pass in a value for the KMS instance in the existing_kms_instance_guid variable. In addition, no policy is created if var.kms_encryption_enabled is set to false."
  default     = false
}

variable "block_storage_volumes" {
  description = "List describing the block storage volumes that will be attached to each vsi"
  type = list(
    object({
      name              = string
      profile           = string
      capacity          = optional(number)
      iops              = optional(number)
      encryption_key    = optional(string)
      resource_group_id = optional(string)
      snapshot_id       = optional(string) # set if you would like to base volume on a snapshot
      tags              = optional(list(string), [])
    })
  )
  default = []
}

variable "load_balancers" {
  description = "Load balancers to add to VSI"
  type = list(
    object({
      name                       = string
      type                       = string
      listener_port              = optional(number)
      listener_port_max          = optional(number)
      listener_port_min          = optional(number)
      listener_protocol          = string
      connection_limit           = optional(number)
      idle_connection_timeout    = optional(number)
      algorithm                  = string
      protocol                   = string
      health_delay               = number
      health_retries             = number
      health_timeout             = number
      health_type                = string
      pool_member_port           = string
      profile                    = optional(string)
      accept_proxy_protocol      = optional(bool)
      subnet_id_to_provision_nlb = optional(string) # Required for Network Load Balancer. If no value is provided, the first one from the VPC subnet list will be selected.
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

##############################################################################


##############################################################################
# Secondary Interface Variables
##############################################################################

variable "existing_secondary_subnet_id" {
  description = "A secondary network interfaces to add to vsi secondary subnets must be in the same zone as VSI. This is only recommended for use with a deployment of 1 VSI."
  type        = string
  default     = null
}

variable "secondary_use_vsi_security_group" {
  description = "Use the security group created by this module in the secondary interface"
  type        = bool
  default     = false
}

variable "secondary_security_groups" {
  description = "The security group IDs to add to the VSI deployment secondary interfaces (5 maximum). Use the same value for interface_name as for name in secondary_subnets to avoid applying the default VPC security group on the secondary network interface."
  type = list(
    object({
      security_group_id = string
      interface_name    = string
    })
  )
  default = []
}

variable "secondary_floating_ips" {
  description = "List of secondary interfaces to add floating ips"
  type        = list(string)
  default     = []
}

variable "secondary_allow_ip_spoofing" {
  description = "Allow IP spoofing on additional network interfaces"
  type        = bool
  default     = false
}

##############################################################################

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

variable "use_legacy_network_interface" {
  description = "Set this to true to use legacy network interface for the created instances."
  type        = bool
  nullable    = false
  default     = false
}

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
