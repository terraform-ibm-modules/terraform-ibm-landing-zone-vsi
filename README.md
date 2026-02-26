# IBM Secure Landing Zone VSI Module

[![Graduated (Supported)](https://img.shields.io/badge/status-Graduated%20(Supported)-brightgreen?style=plastic)](https://terraform-ibm-modules.github.io/documentation/#/badge-status)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
[![latest release](https://img.shields.io/github/v/release/terraform-ibm-modules/terraform-ibm-landing-zone-vsi?logo=GitHub&sort=semver)](https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/releases/latest)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com/)
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-623CE4?logo=terraform)](https://registry.terraform.io/modules/terraform-ibm-modules/landing-zone-vsi/ibm/latest)

This module creates Virtual Server Instances (VSI) across multiple subnets with any number of block storage volumes that are connected by any number of load balancers.
![vsi-module](https://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/main/.docs/vsi-lb.png)

<!-- Below content is automatically populated via pre-commit hook -->
<!-- BEGIN OVERVIEW HOOK -->
## Overview
* [terraform-ibm-landing-zone-vsi](#terraform-ibm-landing-zone-vsi)
* [Submodules](./modules)
    * [fscloud](./modules/fscloud)
* [Examples](./examples)
    * [Basic example using a Snapshot Consistency Group for volumes](./examples/snapshot) [![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-snapshot-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/snapshot)
    * [Complete Example using a placement group, attaching a load balancer, creating secondary interface, and adding additional data volumes](./examples/complete) [![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-complete-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/complete)
    * [End to end basic example using catalog image](./examples/catalog-image) [![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-catalog-image-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/catalog-image)
    * [End to end basic example using gen2 boot volume](./examples/gen2-storage) [![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-gen2-storage-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/gen2-storage)
    * [End to end basic example](./examples/basic) [![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-basic-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/basic)
    * [Example demonstrating the deployment of different sets of VSIs (with different machine types) to the same VPC and subnets, empoying two calls to the module.](./examples/multi-profile-one-vpc) [![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-multi-profile-one-vpc-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/multi-profile-one-vpc)
    * [Financial Services Cloud profile example](./examples/fscloud) [![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-fscloud-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/fscloud)

    ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
* [Deployable Architectures](./solutions)
    * <a href="./solutions/fully-configurable">Cloud automation for  Virtual Server Instance (Fully configurable)</a>
    * <a href="./solutions/quickstart">Cloud automation for Virtual Server Instance (Quickstart)</a>
* [Contributing](#contributing)
<!-- END OVERVIEW HOOK -->

## terraform-ibm-landing-zone-vsi

### Prerequisites

- A VPC
- A VPC SSH key

---

### Virtual servers

This module creates virtual servers across any number of subnets in a single VPC that is connected by a single security group. You can specify the number of virtual servers to provision on each subnet by using the `vsi_per_subnet` variable. Virtual servers use the `prefix` variable to dynamically create names. These names are also used as the Terraform address for each virtual server, which allows for easy reference.

```terraform
module.vsi["test-vsi"].ibm_is_instance.vsi["test-vsi-1"]
module.vsi["test-vsi"].ibm_is_instance.vsi["test-vsi-2"]
module.vsi["test-vsi"].ibm_is_instance.vsi["test-vsi-3"]
```

---

### Block storage volumes

This module creates any number of identical block storage volumes. One storage volume that is specified in the `volumes` variable is created and attached to each virtual server. These block storage volumes use the virtual server name and the volume name to create easily identifiable and manageable addresses within Terraform:

```terraform
module.vsi["test-vsi"].ibm_is_volume.volume["test-vsi-1-one"]
module.vsi["test-vsi"].ibm_is_volume.volume["test-vsi-2-one"]
module.vsi["test-vsi"].ibm_is_volume.volume["test-vsi-3-one"]
module.vsi["test-vsi"].ibm_is_volume.volume["test-vsi-1-two"]
module.vsi["test-vsi"].ibm_is_volume.volume["test-vsi-2-two"]
module.vsi["test-vsi"].ibm_is_volume.volume["test-vsi-3-two"]
```

---

### Reserved IP addresses

By setting the `manage_reserved_ips` to true, this Terraform module will manage VPC reserved IPs for all VSI instances. In the case where the VSI instances would need to be recreated by this module (such as rolling back to a snapshot volume), the new instances will retain the same reserved IP from their previous deployment.

---

### Static boot volume names

The default boot volume names created for VSI instances are four-word random names, which are regenerated if the VSI is recreated. If you set the `use_static_boot_volume_name` to true, the boot volume name for each VSI will not be random and will have a name that will be used again when recreated. This static name is of the format `hostname-boot`. If the VSI is recreated by Terraform for any reason, the exact same boot volume name will be used for the new instance.

Example of static boot volume name: "my-prefix-0a2b-001-boot"

---

### Floating IP addresses

By using the `enable_floating_ip`, a floating IP address is assigned to each VSI created by this module. This floating IP address is displayed in the output, if provisioned.

---

### Load balancers

This module creates any number of application load balancers to balance traffic between all virtual servers that are created by this module. Each load balancer can optionally be added to its own security group. Use the `load_balancers` variable to configure the back-end pool and front-end listener for each load balancer.

---

### Storage Volume Snapshot support

This module supports volume snapshots for both VSI boot volumes and attached block storage volumes. This feature can be used in either of the following scenarios:
1. Create new VSI instances using existing volume snapshots.
2. Roll back currently deployed VSI instances to existing volume snapshots. NOTE: if the boot volume is restored from a snapshot, all VSI instances will be recreated, and will retain most or all of their previous configuration (see note about [Reserved IP addresses above](#reserved-ip-addresses))

There are three methods you can use to specify volume snapshots for your deployment:
1. Specify individual Snapshot CRNs using the `boot_volume_snapshot_crn` and `block_storage_volumes.snapshot_crn` input variables
2. Specify a Snapshot Consistency Group Id using the `snapshot_consistency_group_id` input variable (see explanation below)
3. A combination of specific Snapshot CRNs and Consistency Group Ids, with specific Snapshot CRNs taking precedence over Consistency Group Id snapshots, useful in situations where you may want to override one or more of the Consistency Group snapshots

Snapshot Consistency Group logic explained:
If a `snapshot_consistency_group_id` is passed into this module, the snapshots belonging to that group will be queried for their "service_tags" that were applied at group creation. These tags will contain an index that identifies the snapshot within the group as belonging to either the boot volume of the instance (index 0), or one of the attached block storage volumes (index 1..n). These indexes are used to match up each group snapshot with the boot volume of the instance (which is always index 0), as well as any additional required volumes from the `block_storage_volumes` input variable, using the order of the input variable against the tag index (first `block_storage_volume` in input array = index 1, second = index 2, and so on). If there is a mismatch of group snapshots to the required storage specified in module inputs, then any of the extra snapshots or volumes will simply be ignored in the matching logic.

NOTE: Snapshot and Consistency Group creation are not a part of this module and should be handled elsewhere.

---

### Usage

```terraform
module vsi {
  source                           = "terraform-ibm-modules/landing-zone-vsi/ibm"
  version                          = "X.X.X" # Replace "X.X.X" with a release version to lock into a specific release
  resource_group_id                = var.resource_group_id
  prefix                           = var.prefix
  tags                             = var.tags
  access_tags                      = var.access_tags
  vpc_id                           = var.vpc_id
  subnets                          = var.subnets
  image_id                         = var.image_id
  ssh_key_ids                      = var.ssh_key_ids
  machine_type                     = var.machine_type
  vsi_per_subnet                   = var.vsi_per_subnet
  user_data                        = var.user_data
  boot_volume_encryption_key       = var.boot_volume_encryption_key
  enable_floating_ip               = var.enable_floating_ip
  allow_ip_spoofing                = var.allow_ip_spoofing
  create_security_group            = var.create_security_group
  security_group                   = var.security_group
  security_group_ids               = var.security_group_ids
  block_storage_volumes            = var.block_storage_volumes
  load_balancers                   = var.load_balancers
  secondary_subnets                = var.secondary_subnets
  secondary_use_vsi_security_group = var.secondary_use_vsi_security_group
  secondary_allow_ip_spoofing      = var.secondary_allow_ip_spoofing
}
```

---

## Required IAM access policies
You need the following permissions to run this module.

- Account Management
    - **Resource Group** service
        - `Viewer` platform access
- IAM Services
    - **VPC Infrastructure Services** service
        - `Editor` platform access



<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | >= 1.78.4, < 2.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.1, < 1.0.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_existing_boot_volume_kms_key_crn_parser"></a> [existing\_boot\_volume\_kms\_key\_crn\_parser](#module\_existing\_boot\_volume\_kms\_key\_crn\_parser) | terraform-ibm-modules/common-utilities/ibm//modules/crn-parser | 1.4.2 |

### Resources

| Name | Type |
|------|------|
| [ibm_iam_authorization_policy.block_storage_policy](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/iam_authorization_policy) | resource |
| [ibm_is_floating_ip.secondary_fip](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_floating_ip) | resource |
| [ibm_is_floating_ip.vni_secondary_fip](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_floating_ip) | resource |
| [ibm_is_floating_ip.vsi_fip](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_floating_ip) | resource |
| [ibm_is_instance.vsi](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_instance) | resource |
| [ibm_is_lb.lb](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb) | resource |
| [ibm_is_lb_listener.listener](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb_listener) | resource |
| [ibm_is_lb_pool.pool](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb_pool) | resource |
| [ibm_is_lb_pool_member.alb_pool_members](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb_pool_member) | resource |
| [ibm_is_lb_pool_member.nlb_pool_members](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_lb_pool_member) | resource |
| [ibm_is_security_group.security_group](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group) | resource |
| [ibm_is_security_group_rule.security_group_rules](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_security_group_rule) | resource |
| [ibm_is_subnet_reserved_ip.secondary_vni_ip](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_subnet_reserved_ip) | resource |
| [ibm_is_subnet_reserved_ip.secondary_vsi_ip](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_subnet_reserved_ip) | resource |
| [ibm_is_subnet_reserved_ip.vsi_ip](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_subnet_reserved_ip) | resource |
| [ibm_is_virtual_network_interface.primary_vni](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_virtual_network_interface) | resource |
| [ibm_is_virtual_network_interface.secondary_vni](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_virtual_network_interface) | resource |
| [ibm_is_volume.volume](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/is_volume) | resource |
| [time_sleep.wait_for_authorization_policy](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [ibm_is_image.image_name](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_image) | data source |
| [ibm_is_snapshot.snapshots_from_group](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_snapshot) | data source |
| [ibm_is_snapshot_consistency_group.snapshot_group](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_snapshot_consistency_group) | data source |
| [ibm_is_vpc.vpc](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/data-sources/is_vpc) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_tags"></a> [access\_tags](#input\_access\_tags) | A list of access tags to apply to the VSI resources created by the module. For more information, see https://cloud.ibm.com/docs/account?topic=account-access-tags-tutorial. | `list(string)` | `[]` | no |
| <a name="input_allow_ip_spoofing"></a> [allow\_ip\_spoofing](#input\_allow\_ip\_spoofing) | Allow IP spoofing on the primary network interface | `bool` | `false` | no |
| <a name="input_block_storage_volumes"></a> [block\_storage\_volumes](#input\_block\_storage\_volumes) | List describing the block storage volumes that will be attached to each vsi | <pre>list(<br/>    object({<br/>      name              = string<br/>      profile           = string<br/>      capacity          = optional(number)<br/>      iops              = optional(number)<br/>      encryption_key    = optional(string)<br/>      resource_group_id = optional(string)<br/>      snapshot_crn      = optional(string) # set if you would like to base volume on a snapshot. If you plan to use a snapshot from another account, make sure that the right [IAM authorizations](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=terraform#block-s2s-auth-xaccountrestore-terraform) are in place.<br/>      tags              = optional(list(string), [])<br/>    })<br/>  )</pre> | `[]` | no |
| <a name="input_boot_volume_encryption_key"></a> [boot\_volume\_encryption\_key](#input\_boot\_volume\_encryption\_key) | CRN of boot volume encryption key | `string` | `null` | no |
| <a name="input_boot_volume_iops"></a> [boot\_volume\_iops](#input\_boot\_volume\_iops) | NOTE: custom IOPS value only available for `sdp` volume profile! The custom IOPS value, in GB/s, for the `sdp` boot storage profile. | `number` | `null` | no |
| <a name="input_boot_volume_profile"></a> [boot\_volume\_profile](#input\_boot\_volume\_profile) | The Block Volume Storage Profile to use for the boot volume of the virtual instance, defaults to `general-purpose`. | `string` | `null` | no |
| <a name="input_boot_volume_size"></a> [boot\_volume\_size](#input\_boot\_volume\_size) | The capacity of the volume in gigabytes. This defaults to minimum capacity of the image and maximum to 250 GB | `number` | `null` | no |
| <a name="input_boot_volume_snapshot_crn"></a> [boot\_volume\_snapshot\_crn](#input\_boot\_volume\_snapshot\_crn) | The snapshot CRN of the volume to be used for creating boot volume attachment (if specified, the `image_id` parameter will not be used). If you plan to use a snapshot from another account, make sure that the right [IAM authorizations](https://cloud.ibm.com/docs/vpc?topic=vpc-block-s2s-auth&interface=terraform#block-s2s-auth-xaccountrestore-terraform) are in place. | `string` | `null` | no |
| <a name="input_catalog_offering"></a> [catalog\_offering](#input\_catalog\_offering) | The catalog offering or offering version to use when provisioning this virtual server instance. If an offering is specified, the latest version of that offering will be used. | <pre>object({<br/>    offering_crn = optional(string)<br/>    version_crn  = optional(string)<br/>    plan_crn     = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Create security group for VSI. If this is passed as false, the default will be used | `bool` | n/a | yes |
| <a name="input_custom_vsi_volume_names"></a> [custom\_vsi\_volume\_names](#input\_custom\_vsi\_volume\_names) | A map of subnets, VSI names, and storage volume names. Subnet names should correspond to existing subnets, while VSI and storage volume names are used for resource creation. Example format: { 'subnet\_name\_1': { 'vsi\_name\_1': [ 'storage\_volume\_name\_1', 'storage\_volume\_name\_2' ] } }. If the 'custom\_vsi\_volume\_names' input variable is not set, VSI and volume names are automatically determined using a prefix, the first 4 digits of the subnet\_id, and number padding. In addition, for volume names, the name from the 'block\_storage\_volumes' input variable is also used. | `map(map(list(string)))` | `{}` | no |
| <a name="input_dedicated_host_id"></a> [dedicated\_host\_id](#input\_dedicated\_host\_id) | ID of the dedicated host for hosting the VSI's. The enable\_dedicated\_host input should be set to true if passing a dedicated host ID | `string` | `null` | no |
| <a name="input_enable_dedicated_host"></a> [enable\_dedicated\_host](#input\_enable\_dedicated\_host) | Enabling this option will activate dedicated hosts for the VSIs. When enabled, the dedicated\_host\_id input is required. The default value is set to false. Refer [Understanding Dedicated Hosts](https://cloud.ibm.com/docs/vpc?topic=vpc-creating-dedicated-hosts-instances&interface=ui#about-dedicated-hosts) for more details | `bool` | `false` | no |
| <a name="input_enable_floating_ip"></a> [enable\_floating\_ip](#input\_enable\_floating\_ip) | Create a floating IP for each virtual server created | `bool` | `false` | no |
| <a name="input_image_id"></a> [image\_id](#input\_image\_id) | Image ID used for VSI. Run 'ibmcloud is images' to find available images in a region. Required if not passing a value for `catalog_offering`. | `string` | `null` | no |
| <a name="input_install_logging_agent"></a> [install\_logging\_agent](#input\_install\_logging\_agent) | Set to true to enable installing the logging agent into your VSI at time of creation. If true, values must be passed for `logging_target_host` and either `logging_api_key` or `logging_trusted_profile_id`. Installation logs can be found on the VSI in /run/monitoring-agent/monitoring-agent-install.log. | `bool` | `false` | no |
| <a name="input_install_monitoring_agent"></a> [install\_monitoring\_agent](#input\_install\_monitoring\_agent) | Set to true to install the IBM Cloud Monitoring agent on the provisioned VSI to gather both metrics and security and compliance data. If set to true, values must be passed for `monitoring_access_key`, `monitoring_collector_endpoint` and `monitoring_collector_port`. Installation logs can be found on the VSI in /run/logging-agent/logs-agent-install.log | `bool` | `false` | no |
| <a name="input_kms_encryption_enabled"></a> [kms\_encryption\_enabled](#input\_kms\_encryption\_enabled) | Set this to true to control the encryption keys used to encrypt the data that for the block storage volumes for VPC. If set to false, the data is encrypted by using randomly generated keys. For more info on encrypting block storage volumes, see https://cloud.ibm.com/docs/vpc?topic=vpc-creating-instances-byok | `bool` | `false` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | Load balancers to add to VSI | <pre>list(<br/>    object({<br/>      name                       = string<br/>      type                       = string<br/>      listener_port              = optional(number)<br/>      listener_port_max          = optional(number)<br/>      listener_port_min          = optional(number)<br/>      listener_protocol          = string<br/>      connection_limit           = optional(number)<br/>      idle_connection_timeout    = optional(number)<br/>      algorithm                  = string<br/>      protocol                   = string<br/>      health_delay               = number<br/>      health_retries             = number<br/>      health_timeout             = number<br/>      health_type                = string<br/>      pool_member_port           = string<br/>      profile                    = optional(string)<br/>      accept_proxy_protocol      = optional(bool)<br/>      subnet_id_to_provision_nlb = optional(string) # Required for Network Load Balancer. If no value is provided, the first one from the VPC subnet list will be selected.<br/>      dns = optional(<br/>        object({<br/>          instance_crn = string<br/>          zone_id      = string<br/>        })<br/>      )<br/>      security_group = optional(<br/>        object({<br/>          name = string<br/>          rules = list(<br/>            object({<br/>              name      = string<br/>              direction = string<br/>              source    = string<br/>              tcp = optional(<br/>                object({<br/>                  port_max = number<br/>                  port_min = number<br/>                })<br/>              )<br/>              udp = optional(<br/>                object({<br/>                  port_max = number<br/>                  port_min = number<br/>                })<br/>              )<br/>              icmp = optional(<br/>                object({<br/>                  type = number<br/>                  code = number<br/>                })<br/>              )<br/>            })<br/>          )<br/>        })<br/>      )<br/>    })<br/>  )</pre> | `[]` | no |
| <a name="input_logging_agent_version"></a> [logging\_agent\_version](#input\_logging\_agent\_version) | Version of the logging agent to install. See https://cloud.ibm.com/docs/cloud-logs?topic=cloud-logs-release-notes-agent for list of versions. Only applies if `install_logging_agent` is true. | `string` | `"1.8.0"` | no |
| <a name="input_logging_api_key"></a> [logging\_api\_key](#input\_logging\_api\_key) | API key used by the logging agent to authenticate with IBM Cloud, must be provided if `logging_auth_mode` is set to `IAMAPIKey`. For more information on creating an API key for the logging agent, see https://cloud.ibm.com/docs/cloud-logs?topic=cloud-logs-iam-ingestion-serviceid-api-key. | `string` | `null` | no |
| <a name="input_logging_application_name"></a> [logging\_application\_name](#input\_logging\_application\_name) | The application name defines the environment that produces and sends logs to IBM Cloud Logs. If not provided, the value defaults to `$HOSTNAME`. | `bool` | `null` | no |
| <a name="input_logging_auth_mode"></a> [logging\_auth\_mode](#input\_logging\_auth\_mode) | Authentication mode the logging agent to use to authenticate with IBM Cloud, must be either `IAMAPIKey` or `VSITrustedProfile`. | `string` | `"IAMAPIKey"` | no |
| <a name="input_logging_secure_access_enabled"></a> [logging\_secure\_access\_enabled](#input\_logging\_secure\_access\_enabled) | Set this to true if you have secure access enabled in your VSI. Only applies if 'install\_logging\_agent' is true. | `bool` | `false` | no |
| <a name="input_logging_subsystem_name"></a> [logging\_subsystem\_name](#input\_logging\_subsystem\_name) | The subsystem name is the service or application that produces and sends logs to IBM Cloud Logs. If not provided, the value defaults to `not-found`. | `bool` | `null` | no |
| <a name="input_logging_target_host"></a> [logging\_target\_host](#input\_logging\_target\_host) | Ingestion endpoint that corresponds to the IBM Cloud Logs instance the logging agent connects to. | `string` | `null` | no |
| <a name="input_logging_target_path"></a> [logging\_target\_path](#input\_logging\_target\_path) | Path the logging agent targets when sending logs, defaults to `/logs/v1/singles` for sending logs to an IBM Cloud Logs instance. | `string` | `"/logs/v1/singles"` | no |
| <a name="input_logging_target_port"></a> [logging\_target\_port](#input\_logging\_target\_port) | Port the logging agent targets when sending logs, defaults to `443` for sending logs to an IBM Cloud Logs instance. | `number` | `443` | no |
| <a name="input_logging_trusted_profile_id"></a> [logging\_trusted\_profile\_id](#input\_logging\_trusted\_profile\_id) | Trusted Profile used by the logging agent to access the IBM Cloud Logs instance, must be provided if `logging_auth_mode` is set to `VSITrustedProfile`. | `string` | `null` | no |
| <a name="input_logging_use_private_endpoint"></a> [logging\_use\_private\_endpoint](#input\_logging\_use\_private\_endpoint) | Specifies whether a public or private endpoint is used by the logging agent for IAM authentication. | `bool` | `true` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | VSI machine type. Run 'ibmcloud is instance-profiles' to get a list of regional profiles | `string` | n/a | yes |
| <a name="input_manage_reserved_ips"></a> [manage\_reserved\_ips](#input\_manage\_reserved\_ips) | Set to `true` if you want this terraform module to manage the reserved IP addresses that are assigned to VSI instances. If this option is enabled, when any VSI is recreated it should retain its original IP. | `bool` | `false` | no |
| <a name="input_monitoring_access_key"></a> [monitoring\_access\_key](#input\_monitoring\_access\_key) | Access key used by the IBM Cloud Monitoring agent to successfully forward data to your IBM Cloud Monitoring and SCC Workload Protection instance. Required if `install_monitoring_agent` is true. [Learn more](https://cloud.ibm.com/docs/monitoring?topic=monitoring-access_key). | `string` | `null` | no |
| <a name="input_monitoring_agent_version"></a> [monitoring\_agent\_version](#input\_monitoring\_agent\_version) | Version of the monitoring agent to install. See https://docs.sysdig.com/en/release-notes/linux-host-shield-release-notes for list of versions. Only applies if `install_monitoring_agent` is true. Pass `null` to use latest. | `string` | `"14.4.0"` | no |
| <a name="input_monitoring_collector_endpoint"></a> [monitoring\_collector\_endpoint](#input\_monitoring\_collector\_endpoint) | Endpoint that the IBM Cloud Monitoring agent will forward data to. Required if `install_monitoring_agent` is true. [Learn more](https://cloud.ibm.com/docs/monitoring?topic=monitoring-endpoints#endpoints_ingestion). | `string` | `null` | no |
| <a name="input_monitoring_collector_port"></a> [monitoring\_collector\_port](#input\_monitoring\_collector\_port) | Port the agent targets when sending metrics or compliance data, defaults to `6443`. | `number` | `6443` | no |
| <a name="input_monitoring_tags"></a> [monitoring\_tags](#input\_monitoring\_tags) | A list of tags in the form of `TAG_NAME:TAG_VALUE` to associate with the agent. | `list(string)` | `[]` | no |
| <a name="input_placement_group_id"></a> [placement\_group\_id](#input\_placement\_group\_id) | Unique Identifier of the Placement Group for restricting the placement of the instance, default behaviour is placement on any host | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix to add to all resources created by this module. | `string` | n/a | yes |
| <a name="input_primary_vni_additional_ip_count"></a> [primary\_vni\_additional\_ip\_count](#input\_primary\_vni\_additional\_ip\_count) | The number of secondary reversed IPs to attach to a Virtual Network Interface (VNI). Additional IPs are created only if `manage_reserved_ips` is set to true. | `number` | `0` | no |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | ID of resource group to create VSI and block storage volumes. If you wish to create the block storage volumes in a different resource group, you can optionally set that directly in the 'block\_storage\_volumes' variable. | `string` | n/a | yes |
| <a name="input_secondary_allow_ip_spoofing"></a> [secondary\_allow\_ip\_spoofing](#input\_secondary\_allow\_ip\_spoofing) | Allow IP spoofing on additional network interfaces | `bool` | `false` | no |
| <a name="input_secondary_floating_ips"></a> [secondary\_floating\_ips](#input\_secondary\_floating\_ips) | List of secondary interfaces to add floating ips | `list(string)` | `[]` | no |
| <a name="input_secondary_security_groups"></a> [secondary\_security\_groups](#input\_secondary\_security\_groups) | The security group IDs to add to the VSI deployment secondary interfaces (5 maximum). Use the same value for interface\_name as for name in secondary\_subnets to avoid applying the default VPC security group on the secondary network interface. | <pre>list(<br/>    object({<br/>      security_group_id = string<br/>      interface_name    = string<br/>    })<br/>  )</pre> | `[]` | no |
| <a name="input_secondary_subnets"></a> [secondary\_subnets](#input\_secondary\_subnets) | List of secondary network interfaces to add to vsi secondary subnets must be in the same zone as VSI. This is only recommended for use with a deployment of 1 VSI. | <pre>list(<br/>    object({<br/>      name = string<br/>      id   = string<br/>      zone = string<br/>      cidr = optional(string)<br/>    })<br/>  )</pre> | `[]` | no |
| <a name="input_secondary_use_vsi_security_group"></a> [secondary\_use\_vsi\_security\_group](#input\_secondary\_use\_vsi\_security\_group) | Use the security group created by this module in the secondary interface | `bool` | `false` | no |
| <a name="input_security_group"></a> [security\_group](#input\_security\_group) | Security group created for VSI | <pre>object({<br/>    name = string<br/>    rules = list(<br/>      object({<br/>        name       = string<br/>        direction  = string<br/>        source     = string<br/>        local      = optional(string)<br/>        ip_version = optional(string)<br/>        tcp = optional(<br/>          object({<br/>            port_max = number<br/>            port_min = number<br/>          })<br/>        )<br/>        udp = optional(<br/>          object({<br/>            port_max = number<br/>            port_min = number<br/>          })<br/>        )<br/>        icmp = optional(<br/>          object({<br/>            type = number<br/>            code = number<br/>          })<br/>        )<br/>      })<br/>    )<br/>  })</pre> | `null` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | IDs of additional security groups to be added to VSI deployment primary interface. A VSI interface can have a maximum of 5 security groups. | `list(string)` | `[]` | no |
| <a name="input_skip_iam_authorization_policy"></a> [skip\_iam\_authorization\_policy](#input\_skip\_iam\_authorization\_policy) | Set to true to skip the creation of an IAM authorization policy that permits all Storage Blocks to read the encryption key from the KMS instance. If set to false, pass in a value for the boot volume encryption key in the `boot_volume_encryption_key` variable. In addition, no policy is created if var.kms\_encryption\_enabled is set to false. | `bool` | `false` | no |
| <a name="input_snapshot_consistency_group_id"></a> [snapshot\_consistency\_group\_id](#input\_snapshot\_consistency\_group\_id) | The snapshot consistency group id. If supplied, the group will be queried for snapshots that are matched with both boot volume and attached (attached are matched based on name suffix). You can override specific snapshot CRNs by setting the appropriate input variables as well. | `string` | `null` | no |
| <a name="input_ssh_key_ids"></a> [ssh\_key\_ids](#input\_ssh\_key\_ids) | ssh key ids to use in creating vsi | `list(string)` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | A list of subnet IDs where VSI will be deployed | <pre>list(<br/>    object({<br/>      name = string<br/>      id   = string<br/>      zone = string<br/>      cidr = optional(string)<br/>    })<br/>  )</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | List of tags to apply to resources created by this module. | `list(string)` | `[]` | no |
| <a name="input_use_boot_volume_key_as_default"></a> [use\_boot\_volume\_key\_as\_default](#input\_use\_boot\_volume\_key\_as\_default) | Set to true to use the key specified in the `boot_volume_encryption_key` input as default for all volumes, overriding any key value that may be specified in the `encryption_key` option of the `block_storage_volumes` input variable. If set to `false`,  the value passed for the `encryption_key` option of the `block_storage_volumes` will be used instead. | `bool` | `false` | no |
| <a name="input_use_legacy_network_interface"></a> [use\_legacy\_network\_interface](#input\_use\_legacy\_network\_interface) | Set this to true to use legacy network interface for the created instances. | `bool` | `false` | no |
| <a name="input_use_static_boot_volume_name"></a> [use\_static\_boot\_volume\_name](#input\_use\_static\_boot\_volume\_name) | Sets the boot volume name for each VSI to a static name in the format `{hostname}_boot`, instead of a random name. Set this to `true` to have a consistent boot volume name even when VSIs are recreated. | `bool` | `false` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | User data to initialize VSI deployment | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of VPC | `string` | n/a | yes |
| <a name="input_vsi_per_subnet"></a> [vsi\_per\_subnet](#input\_vsi\_per\_subnet) | Number of VSI instances for each subnet | `number` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_consistency_group_boot_snapshot_crn"></a> [consistency\_group\_boot\_snapshot\_crn](#output\_consistency\_group\_boot\_snapshot\_crn) | The Snapshot CRN used for the VSI boot volume, determined from an optionally supplied consistency group |
| <a name="output_consistency_group_storage_snapshot_crns"></a> [consistency\_group\_storage\_snapshot\_crns](#output\_consistency\_group\_storage\_snapshot\_crns) | Map of attached storage volumes requested, and the Snapshot CRNs that will be used, determined from an optionally supplied consistency group, and mapped |
| <a name="output_fip_list"></a> [fip\_list](#output\_fip\_list) | A list of VSI with name, id, zone, and primary ipv4 address, and floating IP. This list only contains instances with a floating IP attached. |
| <a name="output_ids"></a> [ids](#output\_ids) | The IDs of the VSI |
| <a name="output_lb_security_groups"></a> [lb\_security\_groups](#output\_lb\_security\_groups) | Load Balancer security groups |
| <a name="output_list"></a> [list](#output\_list) | A list of VSI with name, id, zone, and primary ipv4 address |
| <a name="output_load_balancers_metadata"></a> [load\_balancers\_metadata](#output\_load\_balancers\_metadata) | Load Balancers metadata. |
| <a name="output_vsi_security_group"></a> [vsi\_security\_group](#output\_vsi\_security\_group) | Security group for the VSI |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- Leave this section as is so that your module has a link to local development environment set up steps for contributors to follow -->

## Contributing

You can report issues and request features for this module in GitHub issues in the module repo. See [Report an issue or request a feature](https://github.com/terraform-ibm-modules/.github/blob/main/.github/SUPPORT.md).

To set up your local development environment, see [Local development setup](https://terraform-ibm-modules.github.io/documentation/#/local-dev-setup) in the project documentation.
