# End to end basic example using catalog image

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
[![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-catalog-image-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/catalog-image)  
ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
# 
<!-- END SCHEMATICS DEPLOY HOOK -->

An end-to-end basic example that provisions the virtual instance with an image from a catalog offering:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets
- A new placement group
- A VSI in each subnet
- VSI uses a catalog offering image
