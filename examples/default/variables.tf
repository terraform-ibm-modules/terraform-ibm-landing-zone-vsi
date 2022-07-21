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
  default     = "us-south"
}

variable "prefix" {
  description = "The prefix that you would like to append to your resources"
  type        = string
  default     = "test-landing-zone-vsi"
}

variable "resource_tags" {
  description = "List of Tags for the resource created"
  type        = list(string)
  default     = null
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
  default     = true
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
  default = {
    name = "landing-zone-example-sg"
    rules = [
      {
        name      = "lz-rule-inbound-tcp"
        direction = "inbound"
        source    = "0.0.0.0/0"
        tcp = {
          port_min = 1
          port_max = 65535
        }
      },
      {
        name      = "lz-rule-inbound-udp"
        direction = "inbound"
        source    = "0.0.0.0/0"
        udp = {
          port_min = 1
          port_max = 65535
        }
      },
      {
        name      = "lz-rule-outbound-tcp"
        direction = "outbound"
        source    = "0.0.0.0/0"
        tcp = {
          port_min = 1
          port_max = 65535
        }
      },
      {
        name      = "lz-rule-outbound-udp"
        direction = "outbound"
        source    = "0.0.0.0/0"
        udp = {
          port_min = 1
          port_max = 65535
        }
      }
    ]
  }
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
