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
  description = "The name of an existing resource group to provision the resources. If not provided the default resource group will be used."
  default     = null
}

variable "prefix" {
  type        = string
  description = "The prefix to be added to all resources created by this solution. To skip using a prefix, set this value to null or an empty string. The prefix must begin with a lowercase letter and may contain only lowercase letters, digits, and hyphens '-'. It should not exceed 16 characters, must not end with a hyphen('-'), and can not contain consecutive hyphens ('--'). Example: prod-0205-vsi.[Learn more](https://terraform-ibm-modules.github.io/documentation/#/da-implementation-guidelines?id=prefix)."
  nullable    = true
  validation {
    condition = var.prefix == null || var.prefix == "" ? true : alltrue([
      can(regex("^[a-z][-a-z0-9]*[a-z0-9]$", var.prefix)), length(regexall("--", var.prefix)) == 0
    ])
    error_message = "Prefix must begin with a lowercase letter and may contain only lowercase letters, digits, and hyphens '-'. It must not end with a hyphen('-'), and cannot contain consecutive hyphens ('--')."
  }

  validation {
    condition     = var.prefix == null || var.prefix == "" ? true : length(var.prefix) <= 16
    error_message = "Prefix must not exceed 16 characters."
  }
}

variable "provider_visibility" {
  description = "Set the visibility value for the IBM terraform provider. Supported values are `public`, `private`, `public-and-private`. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/guides/custom-service-endpoints)."
  type        = string
  default     = "public"
  nullable    = false

  validation {
    condition     = contains(["public", "private", "public-and-private"], var.provider_visibility)
    error_message = "Invalid value for 'provider_visibility'. Allowed values are 'public', 'private', or 'public-and-private'."
  }
}

variable "resource_tags" {
  description = "The list of tags to add to the Virtual server instance."
  type        = list(string)
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "The list of access tags to add to the Virtual server instance. For more information, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial."
  default     = []
}

##############################################################################
# Virtual server instance Variables
##############################################################################

variable "image_id" {
  description = "Image ID used for Virtual server instance. Run 'ibmcloud is images' to find available images in a region."
  type        = string
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
  description = "Create a floating IP for each virtual server created."
  type        = bool
  default     = false
}

variable "placement_group_id" {
  description = "Unique Identifier of the Placement Group for restricting the placement of the instance, default behaviour is placement on any host."
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

variable "ssh_key" {
  type        = string
  description = "An existing ssh key name to use for this example, if unset a new ssh key will be created"
  default     = null
}

variable "region" {
  description = "The region to which to deploy the VPC"
  type        = string
  default     = "us-south"
}

variable "vpc_name" {
  type        = string
  description = "Name for VPC"
  default     = "qs-vpc"
}

variable "create_security_group" {
  description = "Create security group for VSI"
  type        = string
  default     = false
}

variable "vsi_per_subnet" {
  description = "Number of VSI instances for each subnet"
  type        = number
  default     = 1
}