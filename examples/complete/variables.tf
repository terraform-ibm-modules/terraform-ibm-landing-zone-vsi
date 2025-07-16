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
  description = "The region to which to deploy all resources in this example"
  type        = string
  default     = "us-south"
}

variable "prefix" {
  description = "The prefix that you would like to append to your resources"
  type        = string
  default     = "slz-vsi-com"
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
  default     = "r006-54d5aadd-1907-48ed-8717-22df4fc662b1"
}

variable "ssh_key" {
  type        = string
  description = "An existing ssh key name to use for this example, if unset a new ssh key will be created"
  default     = null
}

variable "secondary_use_vsi_security_group" {
  description = "Use the security group created by this module in the secondary interface"
  type        = bool
  default     = false
}

variable "enable_dedicated_host" {
  type        = bool
  default     = false
  description = "Set the flag to true to provision a dedicated host and deploy VSIs on it. The default value is set to false. Refer [Understanding Dedicated Hosts](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-dedicated-hosts-instances&interface=ui#about-dedicated-hosts) for more details."
}
