# Complete Example using a placement group, attaching a load balancer, creating secondary interface, and adding additional data volumes

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
[![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat-square&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-complete-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/complete)  
ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
# 
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
