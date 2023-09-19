# Profile for IBM Cloud Framework for Financial Services

This code is a version of the [parent root module](../../) that includes a default configuration that complies with the relevant controls from the [IBM Cloud Framework for Financial Services](https://cloud.ibm.com/docs/framework-financial-services?topic=framework-financial-services-about). See the [Example for IBM Cloud Framework for Financial Services](/examples/fscloud/) for logic that uses this module.

The default values in this profile were scanned by [IBM Code Risk Analyzer (CRA)](https://cloud.ibm.com/docs/code-risk-analyzer-cli-plugin?topic=code-risk-analyzer-cli-plugin-cra-cli-plugin#terraform-command) for compliance with the IBM Cloud Framework for Financial Services profile that is specified by the IBM Security and Compliance Center. The scan passed for all applicable goals.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_fscloud_vsi"></a> [fscloud\_vsi](#module\_fscloud\_vsi) | ../../ | n/a |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_ip_spoofing"></a> [allow\_ip\_spoofing](#input\_allow\_ip\_spoofing) | Allow IP spoofing on the primary network interface | `bool` | `false` | no |
| <a name="input_block_storage_volumes"></a> [block\_storage\_volumes](#input\_block\_storage\_volumes) | List describing the block storage volumes that will be attached to each vsi | <pre>list(<br>    object({<br>      name           = string<br>      profile        = string<br>      capacity       = optional(number)<br>      iops           = optional(number)<br>      encryption_key = optional(string)<br>    })<br>  )</pre> | `[]` | no |
| <a name="input_boot_volume_encryption_key"></a> [boot\_volume\_encryption\_key](#input\_boot\_volume\_encryption\_key) | CRN of boot volume encryption key | `string` | n/a | yes |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Create security group for VSI. If this is passed as false, the default will be used | `bool` | n/a | yes |
| <a name="input_enable_floating_ip"></a> [enable\_floating\_ip](#input\_enable\_floating\_ip) | Create a floating IP for each virtual server created | `bool` | `false` | no |
| <a name="input_existing_kms_instance_guid"></a> [existing\_kms\_instance\_guid](#input\_existing\_kms\_instance\_guid) | The GUID of the Hyper Protect Crypto Services or Key Protect instance in which the key specified in var.kms\_key\_crn and var.backup\_encryption\_key\_crn is coming from. Required only if var.kms\_encryption\_enabled is set to true, var.skip\_iam\_authorization\_policy is set to false, and you pass a value for var.kms\_key\_crn, var.backup\_encryption\_key\_crn, or both. | `string` | n/a | yes |
| <a name="input_image_id"></a> [image\_id](#input\_image\_id) | Image ID used for VSI. Run 'ibmcloud is images' to find available images in a region | `string` | n/a | yes |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | Load balancers to add to VSI | <pre>list(<br>    object({<br>      name              = string<br>      type              = string<br>      listener_port     = number<br>      listener_protocol = string<br>      connection_limit  = number<br>      algorithm         = string<br>      protocol          = string<br>      health_delay      = number<br>      health_retries    = number<br>      health_timeout    = number<br>      health_type       = string<br>      pool_member_port  = string<br>      profile           = optional(string)<br>      dns = optional(<br>        object({<br>          instance_crn = string<br>          zone_id      = string<br>        })<br>      )<br>      security_group = optional(<br>        object({<br>          name = string<br>          rules = list(<br>            object({<br>              name      = string<br>              direction = string<br>              source    = string<br>              tcp = optional(<br>                object({<br>                  port_max = number<br>                  port_min = number<br>                })<br>              )<br>              udp = optional(<br>                object({<br>                  port_max = number<br>                  port_min = number<br>                })<br>              )<br>              icmp = optional(<br>                object({<br>                  type = number<br>                  code = number<br>                })<br>              )<br>            })<br>          )<br>        })<br>      )<br>    })<br>  )</pre> | `[]` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | VSI machine type. Run 'ibmcloud is instance-profiles' to get a list of regional profiles | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix that you would like to append to your resources | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | id of resource group to create VPC | `string` | n/a | yes |
| <a name="input_security_group"></a> [security\_group](#input\_security\_group) | Security group created for VSI | <pre>object({<br>    name = string<br>    rules = list(<br>      object({<br>        name      = string<br>        direction = string<br>        source    = string<br>        tcp = optional(<br>          object({<br>            port_max = number<br>            port_min = number<br>          })<br>        )<br>        udp = optional(<br>          object({<br>            port_max = number<br>            port_min = number<br>          })<br>        )<br>        icmp = optional(<br>          object({<br>            type = number<br>            code = number<br>          })<br>        )<br>      })<br>    )<br>  })</pre> | n/a | yes |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | IDs of additional security groups to be added to VSI deployment primary interface. A VSI interface can have a maximum of 5 security groups. | `list(string)` | `[]` | no |
| <a name="input_skip_iam_authorization_policy"></a> [skip\_iam\_authorization\_policy](#input\_skip\_iam\_authorization\_policy) | Set to true to skip the creation of an IAM authorization policy that permits all Storage Blocks to read the encryption key from the KMS instance. If set to false, pass in a value for the KMS instance in the existing\_kms\_instance\_guid variable. In addition, no policy is created if var.kms\_encryption\_enabled is set to false. | `bool` | `false` | no |
| <a name="input_ssh_key_ids"></a> [ssh\_key\_ids](#input\_ssh\_key\_ids) | ssh key ids to use in creating vsi | `list(string)` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | A list of subnet IDs where VSI will be deployed | <pre>list(<br>    object({<br>      name = string<br>      id   = string<br>      zone = string<br>      cidr = string<br>    })<br>  )</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | List of tags to apply to resources created by this module. | `list(string)` | `[]` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | User data to initialize VSI deployment | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of VPC | `string` | n/a | yes |
| <a name="input_vsi_per_subnet"></a> [vsi\_per\_subnet](#input\_vsi\_per\_subnet) | Number of VSI instances for each subnet | `number` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_slz_vsi"></a> [slz\_vsi](#output\_slz\_vsi) | VSI module values |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
