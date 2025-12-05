# End to end basic example using catalog image

An end-to-end basic example that provisions the virtual instance with an image from a catalog offering:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets
- A new placement group
- A VSI in each subnet
- VSI uses a catalog offering image

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<a href="https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-catalog-image-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/catalog-image"><img src="https://img.shields.io/badge/Deploy%20with IBM%20Cloud%20Schematics-0f62fe?logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics" style="height: 16px; vertical-align: text-bottom;"></a>

:information_source: **Tip:** Ctrl/Cmd+Click or right-click for new tab to open deploy buttons in a new tab*
<!-- END SCHEMATICS DEPLOY HOOK -->
