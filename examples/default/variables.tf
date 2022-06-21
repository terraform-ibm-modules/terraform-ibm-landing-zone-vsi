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
  description = "The region to which to deploy the VPC"
  type        = string
  default = "us-south"
}

variable "prefix" {
  description = "The prefix that you would like to append to your resources"
  type        = string
  default = "test-landing-zone-vsi"
}

variable "resource_tags" {
  description = "List of Tags for the resource created"
  type        = list(string)
  default     = null
}

variable "image_id" {
  # Run 'ibmcloud is images' to find available images
  description = "Image ID used for VSI"
  type        = string
  default     = "r026-5c656a84-ce27-4cdd-9345-f11dfab6d12b"
}

variable "machine_type" {
  description = "VSI machine type"
  type        = string
  default     = "cx2d-48x96"
}

variable "create_security_group" {
  description = "Create security group for VSI"
  type        = string
  default     = true
}

variable "user_data" {
  description = "User data to initialize VSI deployment"
  type        = string
  default     = null
}

variable "boot_volume_encryption_key" {
  description = "CRN of boot volume encryption key"
  type        = string
  default     = null
}

variable "ssh_key_ids" {
  description = "SSH key ids to use in creating vsi"
  type        = list(string)
  default     = null
}

variable "vsi_per_subnet" {
  description = "Number of VSI instances for each subnet"
  type        = number
  default     = 1
}
