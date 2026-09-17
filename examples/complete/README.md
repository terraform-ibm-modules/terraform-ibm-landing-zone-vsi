# Complete Example using a placement group, attaching a load balancer, creating secondary interface, and adding additional data volumes

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<p>
  <a href="https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-complete-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/complete">
    <img src="https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics">
  </a><br>
  ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
</p>
<!-- END SCHEMATICS DEPLOY HOOK -->

It will provision the following:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets.
- A new placement group for 3 VSI's
- A VSI in each subnet placed in the placement group.
- A floating IP for each virtual server created.
- A secondary VSI with secondary subnets and secondary security group.
- **(Optional) A dedicated host and a dedicated host group.** - Disabled by default.
- **(Optional) A VSI will be created on the dedicated host if enabled.**
- A new Application Load Balancer and Network Load Balancer to balance traffic between all virtual servers that are created by this example.

> Note: The Dedicated Host module is disabled by default . If you need to deploy a dedicated host, you must explicitly enable it by setting `enable_dedicated_host = true`

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 2.5.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.4 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ibm"></a> [ibm](#provider\_ibm) | 2.6.2 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.4.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dedicated_host"></a> [dedicated\_host](#module\_dedicated\_host) | terraform-ibm-modules/dedicated-host/ibm | 2.0.21 |
| <a name="module_key_protect_all_inclusive"></a> [key\_protect\_all\_inclusive](#module\_key\_protect\_all\_inclusive) | terraform-ibm-modules/kms-all-inclusive/ibm | 5.6.9 |
| <a name="module_logging"></a> [logging](#module\_logging) | terraform-ibm-modules/cloud-logs/ibm | 1.15.10 |
| <a name="module_monitoring"></a> [monitoring](#module\_monitoring) | terraform-ibm-modules/cloud-monitoring/ibm | 1.15.15 |
| <a name="module_resource_group"></a> [resource\_group](#module\_resource\_group) | terraform-ibm-modules/resource-group/ibm | 1.6.1 |
| <a name="module_server_cert"></a> [server\_cert](#module\_server\_cert) | terraform-ibm-modules/secrets-manager-private-cert/ibm | 1.12.10 |
| <a name="module_slz_vpc"></a> [slz\_vpc](#module\_slz\_vpc) | terraform-ibm-modules/landing-zone-vpc/ibm | 10.0.6 |
| <a name="module_slz_vsi"></a> [slz\_vsi](#module\_slz\_vsi) | ../../ | n/a |
| <a name="module_slz_vsi_dh"></a> [slz\_vsi\_dh](#module\_slz\_vsi\_dh) | ../../ | n/a |
| <a name="module_vsi_image_selector"></a> [vsi\_image\_selector](#module\_vsi\_image\_selector) | terraform-ibm-modules/common-utilities/ibm//modules/vsi-image-selector | 1.9.0 |

## Resources

| Name | Type |
|------|------|
| [ibm_is_placement_group.placement_group](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_placement_group) | resource |
| [ibm_is_security_group.secondary_security_group](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group) | resource |
| [ibm_is_ssh_key.ssh_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_ssh_key) | resource |
| [ibm_is_subnet.secondary_subnet](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_subnet) | resource |
| [ibm_is_vpc_address_prefix.secondary_address_prefixes](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_vpc_address_prefix) | resource |
| [tls_private_key.tls_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [ibm_is_ssh_key.existing_ssh_key](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_ssh_key) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_tags"></a> [access\_tags](#input\_access\_tags) | A list of access tags to apply to the VSI resources created by the module. | `list(string)` | `[]` | no |
| <a name="input_enable_dedicated_host"></a> [enable\_dedicated\_host](#input\_enable\_dedicated\_host) | Set the flag to true to provision a dedicated host and deploy VSIs on it. The default value is set to false. Refer [Understanding Dedicated Hosts](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-dedicated-hosts-instances&interface=ui#about-dedicated-hosts) for more details. | `bool` | `false` | no |
| <a name="input_existing_sm_cert_template"></a> [existing\_sm\_cert\_template](#input\_existing\_sm\_cert\_template) | Name of the private certificate template to use when issuing the server certificate from the Secrets Manager instance | `string` | `null` | no |
| <a name="input_existing_sm_instance_guid"></a> [existing\_sm\_instance\_guid](#input\_existing\_sm\_instance\_guid) | GUID of an existing Secrets Manager instance that has a private certificate engine configured | `string` | `null` | no |
| <a name="input_existing_sm_instance_region"></a> [existing\_sm\_instance\_region](#input\_existing\_sm\_instance\_region) | Region of the existing Secrets Manager instance | `string` | `null` | no |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | APIkey that's associated with the account to provision resources to | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix that you would like to append to your resources | `string` | `"slz-vsi-com"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region to which to deploy all resources in this example | `string` | `"us-south"` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | An existing resource group name to use for this example, if unset a new resource group will be created | `string` | `null` | no |
| <a name="input_resource_tags"></a> [resource\_tags](#input\_resource\_tags) | List of Tags for the resource created | `list(string)` | `[]` | no |
| <a name="input_secondary_use_vsi_security_group"></a> [secondary\_use\_vsi\_security\_group](#input\_secondary\_use\_vsi\_security\_group) | Use the security group created by this module in the secondary interface | `bool` | `false` | no |
| <a name="input_ssh_key"></a> [ssh\_key](#input\_ssh\_key) | An existing ssh key name to use for this example, if unset a new ssh key will be created | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lb_security_groups"></a> [lb\_security\_groups](#output\_lb\_security\_groups) | Load Balancer security groups |
| <a name="output_load_balancers_metadata"></a> [load\_balancers\_metadata](#output\_load\_balancers\_metadata) | Load Balancers metadata. |
| <a name="output_secondary_security_groups"></a> [secondary\_security\_groups](#output\_secondary\_security\_groups) | Secondary security groups created |
| <a name="output_secondary_subnets"></a> [secondary\_subnets](#output\_secondary\_subnets) | Secondary subnets created |
| <a name="output_slz_vpc"></a> [slz\_vpc](#output\_slz\_vpc) | VPC module values |
| <a name="output_slz_vsi"></a> [slz\_vsi](#output\_slz\_vsi) | VSI module values |
| <a name="output_slz_vsi_dh"></a> [slz\_vsi\_dh](#output\_slz\_vsi\_dh) | VSI module values |
<!-- END_TF_DOCS -->
