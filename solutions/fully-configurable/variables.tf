########################################################################################################################
# Input variables
########################################################################################################################

variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API key used to provision resources."
  sensitive   = true
}

variable "existing_resource_group_name" {
  type        = string
  description = "The name of an existing resource group to provision resources in."
  default     = "Default"
  nullable    = false
}

variable "prefix" {
  type        = string
  description = "The prefix to add to all resources that this solution creates (e.g `prod`, `test`, `dev`). To not use any prefix value, you can set this value to `null` or an empty string."
  nullable    = true
  validation {
    condition = (var.prefix == null ? true :
      alltrue([
        can(regex("^[a-z]{0,1}[-a-z0-9]{0,14}[a-z0-9]{0,1}$", var.prefix)),
        length(regexall("^.*--.*", var.prefix)) == 0
      ])
    )
    error_message = "Prefix must begin with a lowercase letter, contain only lowercase letters, numbers, and - characters. Prefixes must end with a lowercase letter or number and be 16 or fewer characters."
  }
}

variable "provider_visibility" {
  description = "Set the visibility value for the IBM terraform provider. Supported values are `public`, `private`, `public-and-private`. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/guides/custom-service-endpoints)."
  type        = string
  default     = "private"
  nullable    = false

  validation {
    condition     = contains(["public", "private", "public-and-private"], var.provider_visibility)
    error_message = "Invalid value for 'provider_visibility'. Allowed values are 'public', 'private', or 'public-and-private'."
  }
}

variable "region" {
  type        = string
  default     = "us-south"
  description = "The region to provision Virtual server instance resources in."
  nullable    = false
}

variable "vsi_resource_tags" {
  description = "The list of tags to add to the Virtual server instance."
  type        = list(string)
  default     = []
}

variable "vsi_access_tags" {
  type        = list(string)
  description = "The list of access tags to add to the Virtual server instance. For more information, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial."
  default     = []
}

##############################################################################


##############################################################################
# VPC Variables
##############################################################################

variable "existing_subnet_id" {
  description = "The ID of an existing subnet."
  type        = string
}

##############################################################################


##############################################################################
# Virtual server instance Variables
##############################################################################

variable "vsi_name" {
  description = "The name of the Virtual server instance."
  type        = string
  default     = "vsi"
}

variable "image_id" {
  description = "Image ID used for Virtual server instance. Run 'ibmcloud is images' to find available images in a region."
  type        = string
  nullable    = false
}

variable "ssh_public_keys" {
  description = "List of public SSH keys for Virtual server instance creation which does not already exist in the deployment region. Must be an RSA key with a key size of either 2048 bits or 4096 bits (recommended) - See https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys. To use an existing keys, select values for the variable `existing_ssh_key_ids` instead."
  type        = list(string)
  default     = []

  validation {
    error_message = "Public SSH Key must be a valid ssh rsa public key."
    condition     = alltrue([for ssh in var.ssh_public_keys : can(regex("ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3} ?([^@]+@[^@]+)?", ssh))])
  }

  validation {
    condition     = var.auto_generate_ssh_key ? true : length(var.ssh_public_keys) > 0 || length(var.existing_ssh_key_ids) > 0 ? true : false
    error_message = "Please provide a value for either `ssh_public_keys` or `existing_ssh_key_ids`, when `auto_generate_ssh_key` is set to false."
  }
}

variable "existing_ssh_key_ids" {
  description = "The IDs of existing SSH keys to use while creating Virtual server instance."
  type        = list(string)
  default     = []
}

variable "auto_generate_ssh_key" {
  description = "An SSH key pair (a public and private key) is automatically generated for you. The private key is outputted as an sensitive value which can be stored in the secret mananger. The public key is stored in your VPC and you can download it from the SSH key details page."
  type        = bool
  default     = true
  nullable    = false
}

variable "machine_type" {
  description = "The Virtual server instance machine type. Run 'ibmcloud is instance-profiles' to get a list of regional profiles."
  type        = string
  default     = "cx2-2x4"
}

variable "user_data" {
  description = "The user data that automatically performs common configuration tasks or runs scripts. When using the user_data variable in your configuration, it's essential to provide the content in the correct format for it to be properly recongnized by the terraform. Use <<-EOT and EOT to enclose your user_data content to ensure it's passed as multi-line string. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-user-data)"
  type        = string
  default     = null
}

########################################################################################################################
# KMS variables
########################################################################################################################

variable "use_boot_volume_key_as_default" {
  description = "Set to true to use the boot volume encryption key as default for all volumes, overriding any key value that may be specified in the `encryption_key` option of the `block_storage_volumes` input variable. If set to `false`,  the value passed for the `encryption_key` option of the `block_storage_volumes` will be used instead."
  type        = bool
  default     = false
}

variable "kms_encryption_enabled_boot_volume" {
  type        = bool
  description = "Set this to true to control the encryption keys used to encrypt the data that for the block storage volumes for VPC. If set to false, the data is encrypted by using randomly generated keys. For more info on encrypting block storage volumes, see https://cloud.ibm.com/docs/vpc?topic=vpc-creating-instances-byok"
  default     = false
  nullable    = false

  validation {
    condition     = var.existing_kms_instance_crn != null ? var.kms_encryption_enabled_boot_volume : true
    error_message = "If passing a value for 'existing_kms_instance_crn', you should set 'kms_encryption_enabled_boot_volume' to true."
  }

  validation {
    condition     = var.existing_boot_volume_kms_key_crn != null ? var.kms_encryption_enabled_boot_volume : true
    error_message = "If passing a value for 'existing_boot_volume_kms_key_crn', you should set 'kms_encryption_enabled_boot_volume' to true."
  }

  validation {
    condition     = var.kms_encryption_enabled_boot_volume ? ((var.existing_boot_volume_kms_key_crn != null || var.existing_kms_instance_crn != null) ? true : false) : true
    error_message = "Either 'existing_boot_volume_kms_key_crn' or 'existing_kms_instance_crn' is required if 'kms_encryption_enabled_boot_volume' is set to true."
  }
}

variable "existing_boot_volume_kms_key_crn" {
  type        = string
  default     = null
  description = "The CRN of an existing KMS key to use to encrypt the the block storage volumes for VPC. If no value is set for this variable, specify a value for either the `existing_kms_instance_crn` variable to create a key ring and key."

  validation {
    condition = anytrue([
      can(regex("^crn:(.*:){3}(kms|hs-crypto):(.*:){2}[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}:key:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.existing_boot_volume_kms_key_crn)),
      var.existing_boot_volume_kms_key_crn == null,
    ])
    error_message = "The provided KMS key CRN in the input 'existing_boot_volume_kms_key_crn' in not valid."
  }
}

variable "existing_kms_instance_crn" {
  type        = string
  default     = null
  description = "The CRN of an existing KMS instance (Hyper Protect Crypto Services or Key Protect). Used to create a new KMS key unless an existing key is passed using the `existing_boot_volume_kms_key_crn` input. If the KMS instance is in different account you must also provide a value for `ibmcloud_kms_api_key`."

  validation {
    condition = anytrue([
      can(regex("^crn:(.*:){3}(kms|hs-crypto):(.*:){2}[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}::$", var.existing_kms_instance_crn)),
      var.existing_kms_instance_crn == null,
    ])
    error_message = "The provided KMS instance CRN in the input 'existing_kms_instance_crn' in not valid."
  }
}

variable "force_delete_kms_key" {
  type        = bool
  default     = false
  nullable    = false
  description = "If creating a new KMS key, toggle whether is should be force deleted or not on undeploy."
}

variable "skip_block_storage_kms_iam_auth_policy" {
  type        = bool
  description = "Set to true to skip the creation of an IAM authorization policy that permits all Storage Blocks to read the encryption key from the KMS instance. If set to false, pass in a value for the KMS instance in the existing_kms_instance_guid variable. In addition, no policy is created if `kms_encryption_enabled_boot_volume` is set to false."
  default     = false
}

variable "boot_volume_key_ring_name" {
  type        = string
  default     = "boot-volume-key-ring"
  description = "The name for the key ring created for the block storage volumes key. Applies only if not specifying an existing key. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

variable "boot_volume_key_name" {
  type        = string
  default     = "boot-volume-key"
  description = "The name for the key created for the block storage volumes. Applies only if not specifying an existing key. If a prefix input variable is specified, the prefix is added to the name in the `<prefix>-<name>` format."
}

variable "kms_endpoint_type" {
  type        = string
  description = "The endpoint for communicating with the KMS instance. Possible values: `public`, `private`. Applies only if `kms_encryption_enabled_boot_volume` is true"
  default     = "private"
  nullable    = false
  validation {
    condition     = can(regex("public|private", var.kms_endpoint_type))
    error_message = "The kms_endpoint_type value must be 'public' or 'private'."
  }
}

variable "ibmcloud_kms_api_key" {
  type        = string
  description = "The IBM Cloud API key that can create a root key and key ring in the key management service (KMS) instance. If not specified, the 'ibmcloud_api_key' variable is used. Specify this key if the instance in `existing_kms_instance_crn` is in an account that's different from the Virtual server instance. Leave this input empty if the same account owns both instances."
  sensitive   = true
  default     = null
}

########################################################################################################################

variable "manage_reserved_ips" {
  description = "Set to `true` if you want this terraform to manage the reserved IP addresses that are assigned to Virtual server instance. If this option is enabled, when any Virtual server instance is recreated it should retain its original IP."
  type        = bool
  default     = false
}

variable "primary_virtual_network_interface_additional_ip_count" {
  description = "The number of secondary reversed IPs to attach to a Virtual Network Interface (VNI). Additional IPs are created only if `manage_reserved_ips` is set to true."
  type        = number
  nullable    = false
  default     = 0
}

variable "use_static_boot_volume_name" {
  description = "Sets the boot volume name for each Virtual server instance to a static name in the format `{hostname}-boot`, instead of a random name. Set this to `true` to have a consistent boot volume name even when Virtual server instance is recreated."
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

variable "placement_group_id" {
  description = "Unique Identifier of the Placement Group for restricting the placement of the instance, default behaviour is placement on any host"
  type        = string
  default     = null
}

variable "security_group" {
  description = "The security group for Virtual server instance. If no value is passed, the VPC default security group will be used. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/solutions/fully-configurable/DA_inputs.md#options-with-security-group)."
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
  description = "IDs of additional security groups to be added to Virtual server instance deployment primary interface. A Virtual server instance interface can have a maximum of 5 security groups."
  type        = list(string)
  default     = []
}

variable "block_storage_volumes" {
  description = "The list describing the block storage volumes that will be attached to the Virtual server instance. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/solutions/fully-configurable/DA_inputs.md#options-with-block-vol)."
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
  description = "The load balancers to add to Virtual server instance. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/solutions/fully-configurable/DA_inputs.md#options-with-load-balancers)."
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
  description = "A secondary network interfaces to add to Virtual server instance secondary subnets must be in the same zone as Virtual server instance. This is only recommended for use with a deployment of 1 Virtual server instance."
  type        = string
  default     = null
}

variable "secondary_use_vsi_security_group" {
  description = "Use the security group created by this deployable architecture in the secondary interface."
  type        = bool
  default     = false
}

variable "secondary_security_groups" {
  description = "The security group IDs to add to the Virtual server instance deployment secondary interfaces (5 maximum). Use the same value for interface_name as for name in secondary_subnets to avoid applying the default VPC security group on the secondary network interface. [Learn more](https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/solutions/fully-configurable/DA_inputs.md#options-with-secondary-security-groups)."
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
# Dedicated Host Variables
##############################################################################

variable "dedicated_host_id" {
  type        = string
  default     = null
  description = "The ID of the dedicated host for hosting the Virtual server instance's."
}

##############################################################################

##############################################################################
## Secrets Manager Service Credentials
##############################################################################

variable "existing_secrets_manager_instance_crn" {
  type        = string
  default     = null
  description = "The CRN of existing secrets manager to use to store the SSH private key which was auto generated when `auto_generate_ssh_key` was set to true."
  validation {
    condition     = var.auto_generate_ssh_key ? var.existing_secrets_manager_instance_crn != null ? true : false : true
    error_message = "`existing_secrets_manager_instance_crn` is a required value when `auto_generate_ssh_key` is set to true."
  }
}

variable "existing_secrets_manager_endpoint_type" {
  type        = string
  description = "The endpoint type to use if `existing_secrets_manager_instance_crn` is specified. Possible values: public, private."
  default     = "private"
  validation {
    condition     = contains(["public", "private"], var.existing_secrets_manager_endpoint_type)
    error_message = "Only \"public\" and \"private\" are allowed values for 'existing_secrets_endpoint_type'."
  }
}

variable "ssh_key_secret_group_name" {
  type        = string
  default     = "ssh-key-secret-group"
  nullable    = false
  description = "The name for the secret group created for the auto generated ssh private key."
}

variable "ssh_key_secret_name" {
  type        = string
  default     = "ssh-key-secret"
  nullable    = false
  description = "The name for the secret created for the auto generated ssh private key."
}
