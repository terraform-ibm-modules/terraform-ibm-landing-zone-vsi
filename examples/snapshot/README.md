# Basic example using a Snapshot Consistency Group for volumes

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
[![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-snapshot-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/snapshot)  
ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
# 
<!-- END SCHEMATICS DEPLOY HOOK -->

An end-to-end basic example that will provision the following, using previously created snapshots for storage volumes:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets
- A VSI in each subnet
- Two additional block storage attached to each VSI
- Reserved and Floating IPs managed by Terraform for each VSI
- Boot volume and additional storage volumes will be based on snapshots from consistency group, if ID is supplied
