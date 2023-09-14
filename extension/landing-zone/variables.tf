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
  default     = "au-syd"
}

variable "prefix" {
  description = "The prefix that you would like to append to your resources"
  type        = string
  default     = "slz-vsi"
}

variable "vpc_id" {
  description = "Id of the VPC in which the VSI will be created."
  type        = string
  default     = "r026-9c433ed0-69f5-4554-ab35-c86d01ef1b6c"
}

variable "ssh_key" {
  type        = string
  description = "An existing ssh key name to use for this example, if unset a new ssh key will be created"
  default     = null
}

variable "resource_tags" {
  description = "List of Tags for the resource created"
  type        = list(string)
  default     = null
}

variable "access_tags" {
  type        = list(string)
  description = "A list of access tags to apply to the VSI resources created by the module."
  default     = []
}

variable "image_name" {
  description = "Image ID used for VSI. Run 'ibmcloud is images' to find available images. Be aware that region is important for the image since the id's are different in each region."
  type        = string
  default     = "ibm-ubuntu-18-04-6-minimal-amd64-2"
}

variable "machine_type" {
  description = "VSI machine type"
  type        = string
  default     = "cx2-2x4"
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
  description = "The GUID of the Hyper Protect Crypto Services or Key Protect instance in which the key specified in var.kms_key_crn and var.backup_encryption_key_crn is coming from. Required only if var.kms_encryption_enabled is set to true, var.skip_iam_authorization_policy is set to false, and you pass a value for var.kms_key_crn, var.backup_encryption_key_crn, or both."
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

  validation {
    error_message = "Security group IDs must be unique."
    condition     = length(var.security_group_ids) == length(distinct(var.security_group_ids))
  }

  validation {
    error_message = "No more than 5 security groups can be added to a VSI deployment."
    condition     = length(var.security_group_ids) <= 5
  }
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

  validation {
    error_message = "Each block storage volume must have a unique name."
    condition     = length(distinct(var.block_storage_volumes[*].name)) == length(var.block_storage_volumes)
  }
}
variable "enable_floating_ip" {
  description = "Create a floating IP for each virtual server created"
  type        = bool
  default     = false
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

  validation {
    error_message = "Load balancer names must match the regex pattern ^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$."
    condition = length(distinct(
      flatten([
        # Check through rules
        for load_balancer in var.load_balancers :
        # Return false if direction is not valid
        false if !can(regex("^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$", load_balancer.name))
      ])
    )) == 0
  }

  validation {
    error_message = "Load Balancer Pool algorithm can only be `round_robin`, `weighted_round_robin`, or `least_connections`."
    condition = length(
      flatten([
        for load_balancer in var.load_balancers :
        true if !contains(["round_robin", "weighted_round_robin", "least_connections"], load_balancer.algorithm)
      ])
    ) == 0
  }

  validation {
    error_message = "Load Balancer Pool Protocol can only be `http`, `https`, or `tcp`."
    condition = length(
      flatten([
        for load_balancer in var.load_balancers :
        true if !contains(["http", "https", "tcp"], load_balancer.protocol)
      ])
    ) == 0
  }

  validation {
    error_message = "Pool health delay must be greater than the timeout."
    condition = length(
      flatten([
        for load_balancer in var.load_balancers :
        true if load_balancer.health_delay < load_balancer.health_timeout
      ])
    ) == 0
  }

  validation {
    error_message = "Load Balancer Pool Health Check Type can only be `http`, `https`, or `tcp`."
    condition = length(
      flatten([
        for load_balancer in var.load_balancers :
        true if !contains(["http", "https", "tcp"], load_balancer.health_type)
      ])
    ) == 0
  }

  validation {
    error_message = "Each load balancer must have a unique name."
    condition     = length(distinct(var.load_balancers[*].name)) == length(var.load_balancers[*].name)
  }
}
