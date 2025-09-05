########################################################################################################################
# Input variables
########################################################################################################################

variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud API key used to provision resources."
  sensitive   = true
}

variable "region" {
  type        = string
  description = "Region in which all the resources will be deployed. [Learn More](https://terraform-ibm-modules.github.io/documentation/#/region)."
  default     = "us-south"
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

variable "vpc_name" {
  type        = string
  description = "Name of the Virtual Private Cloud (VPC) in which resources will be deployed. [Learn more](https://cloud.ibm.com/docs/vpc)"
  default     = "qs-vpc"
}

variable "provider_visibility" {
  description = "Set the visibility value for the IBM terraform provider. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/guides/custom-service-endpoints)."
  type        = string
  default     = "private"

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

variable "vsi_name" {
  description = "The name of the Virtual server instance."
  type        = string
  default     = "qs-vsi"
}

variable "image_name" {
  description = "Image ID used for Virtual server instance. Run 'ibmcloud is images' to find available images in a region. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-about-images)"
  type        = string
}

variable "machine_type" {
  description = "The Virtual server instance machine type. Run 'ibmcloud is instance-profiles' to get a list of regional profiles. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-profiles&interface=ui)."
  type        = string
  default     = "bx2-2x8"
}

variable "user_data" {
  description = "The user data that automatically performs common configuration tasks or runs scripts. When using the user_data variable in your configuration, it's essential to provide the content in the correct format for it to be properly recognized by the terraform. Use <<-EOT and EOT to enclose your user_data content to ensure it's passed as multi-line string. [Learn more](https://cloud.ibm.com/docs/vpc?topic=vpc-user-data)"
  type        = string
  default     = null
}

variable "enable_floating_ip" {
  description = "Create a floating IP for each virtual server created."
  type        = bool
  default     = true
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

variable "existing_ssh_key_name" {
  type        = string
  description = "An existing ssh key name to use for this example, if unset a new ssh key will be created"
  default     = null
}
