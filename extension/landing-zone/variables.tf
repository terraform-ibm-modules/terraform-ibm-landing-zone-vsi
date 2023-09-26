variable "ibmcloud_api_key" {
  description = "The API key that's associated with the account to provision resources to"
  type        = string
  sensitive   = true
}

variable "resource_group" {
  type        = string
  description = "Resource Group name of the existing landing zone VPC."
}

variable "region" {
  description = "The region of the existing landing zone VPC."
  type        = string
}

variable "prefix" {
  description = "The prefix that you would like to append to VSI, Block Storage, Security Group, Floating IP and Load Balancer."
  type        = string
  default     = "slz-vsi"
}

variable "vpc_id" {
  description = "The ID of the VPC where the VSI will be created."
  type        = string
}

variable "ssh_keys" {
  description = "SSH keys to use to provision a VSI. Must be an RSA key with a key size of either 2048 bits or 4096 bits (recommended). If `public_key` is not provided, the named key will be looked up from data. See https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys."
  type = object({
    name       = string
    public_key = optional(string)
  })

  validation {
    error_message = "Public SSH Key must be a valid ssh rsa public key."
    condition     = var.ssh_keys.public_key == null || can(regex("ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3} ?([^@]+@[^@]+)?", var.ssh_keys.public_key))
  }
}

variable "resource_tags" {
  description = "List of tags for the VSI, Block Storage, Security Group, Floating IP and Load Balancer created"
  type        = list(string)
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the VSI resources created by the module."
  default     = []
}

variable "image_name" {
  description = "Image ID used for VSI. Run 'ibmcloud is images' to find available images. Be aware that region is important for the image since the id's are different in each region."
  type        = string
  default     = "ibm-ubuntu-22-04-2-minimal-amd64-1"
}

variable "machine_type" {
  description = "VSI machine type"
  type        = string
  default     = "cx2-2x4"
}

variable "security_group" {
  description = "Security group created for the VSI"
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
    "name" : "management",
    "rules" : [
      {
        "direction" : "inbound",
        "name" : "allow-ibm-inbound",
        "source" : "161.26.0.0/16"
      },
      {
        "direction" : "inbound",
        "name" : "allow-vpc-inbound",
        "source" : "10.0.0.0/8"
      },
      {
        "direction" : "outbound",
        "name" : "allow-vpc-outbound",
        "source" : "10.0.0.0/8"
      },
      {
        "direction" : "outbound",
        "name" : "allow-ibm-tcp-53-outbound",
        "source" : "161.26.0.0/16",
        "tcp" : {
          "port_max" : 53,
          "port_min" : 53
        }
      },
      {
        "direction" : "outbound",
        "name" : "allow-ibm-tcp-80-outbound",
        "source" : "161.26.0.0/16",
        "tcp" : {
          "port_max" : 80,
          "port_min" : 80
        }
      },
      {
        "direction" : "outbound",
        "name" : "allow-ibm-tcp-443-outbound",
        "source" : "161.26.0.0/16",
        "tcp" : {
          "port_max" : 443,
          "port_min" : 443
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
}

variable "existing_kms_instance_guid" {
  description = "The GUID of the KMS instance in which the key specified in var.boot_volume_encryption_key is coming from."
  type        = string
}

variable "skip_iam_authorization_policy" {
  type        = bool
  description = "Set to true to skip the creation of an IAM authorization policy that permits all Storage Blocks to read the encryption key from the KMS instance. If set to false, pass in a value for the KMS instance in the existing_kms_instance_guid variable."
  default     = false
}

variable "vsi_per_subnet" {
  description = "Number of VSI instances for each subnet"
  type        = number
  default     = 1
}

variable "subnet_names" {
  description = "Subnets to which the VSI instances should be deployed"
  type        = list(string)
  default = [
    "vpe-zone-1",
    "vpe-zone-2",
    "vpe-zone-3"
  ]
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
    })
  )
  default = []
}

variable "enable_floating_ip" {
  description = "Create a floating IP for each virtual server created"
  type        = bool
  default     = false
}

variable "placement_group_id" {
  description = "Unique Identifier of the Placement Group for restricting the placement of the instance, default behaviour is placement on any host"
  type        = string
  default     = null
}

variable "load_balancers" {
  description = "Load balancers to add to VSI"
  type = list(
    object({
      name              = string
      type              = string
      listener_port     = number
      listener_protocol = string
      connection_limit  = number
      algorithm         = string
      protocol          = string
      health_delay      = number
      health_retries    = number
      health_timeout    = number
      health_type       = string
      pool_member_port  = string
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
