variable "ibmcloud_api_key" {
  description = "APIkey that's associated with the account to provision resources to"
  type        = string
  sensitive   = true
}

variable "resource_group" {
  type        = string
  description = "An existing resource group name to use for this example, if unset a new resource group will be created"
  default     = null
}

variable "region" {
  description = "The region to which to deploy all resources created by this example"
  type        = string
  default     = "us-south"
}

variable "prefix" {
  description = "The prefix that you would like to append to your resources"
  type        = string
  default     = "vsi-sec-int"
}

variable "resource_tags" {
  description = "List of Tags for the resource created"
  type        = list(string)
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the VSI resources created by the module."
  default     = []
}

variable "image_id" {
  description = "Image ID used for VSI. Run 'ibmcloud is images' to find available images. Be aware that region is important for the image since the id's are different in each region."
  type        = string
  default     = "r006-1366d3e6-bf5b-49a0-b69a-8efd93cc225f"
}

variable "machine_type" {
  description = "VSI machine type"
  type        = string
  default     = "cx2-2x4"
}

variable "create_security_group" {
  description = "Create security group for VSI"
  type        = string
  default     = false
}

variable "user_data" {
  description = "User data to initialize VSI deployment"
  type        = string
  default     = null
}

variable "vsi_per_subnet" {
  description = "Number of VSI instances for each subnet"
  type        = number
  default     = 1
}

variable "ssh_key" {
  type        = string
  description = "An existing ssh key name to use for this example, if unset a new ssh key will be created"
  default     = null
}

variable "vpc_name" {
  type        = string
  description = "Name for VPC"
  default     = "vpc"
}

##############################################################################
# Secondary Interface Variables
##############################################################################

variable "secondary_use_vsi_security_group" {
  description = "Use the security group created by this module in the secondary interface"
  type        = bool
  default     = false
}

##############################################################################
