# Financial Services Cloud profile example

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
[![Deploy with IBM Cloud Schematics](https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat-square&logo=ibm&logoColor=white&labelColor=0f62fe)](https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-fscloud-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/fscloud)  
ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
# 
<!-- END SCHEMATICS DEPLOY HOOK -->

An end-to-end example that uses the [Profile for IBM Cloud Framework for Financial Services](https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/modules/fscloud) to deploy a VSI.

The example uses the IBM Cloud Terraform provider to create the following infrastructure:
* A resource group, if one is not passed in.
* An SSH Key, if one is not passed in.
* A Secure Landing Zone virtual private cloud (VPC).
* An IBM Cloud VSI instance with Hyper Protect Crypto Services root key that is passed in for encrypting block storage.
* Additional data volumes on each VSI

:exclamation: **Important:** In this example, only the VSI instance complies with the IBM Cloud Framework for Financial Services. Other parts of the infrastructure do not necessarily comply.

## Before you begin

- You need a Hyper Protect Crypto Services instance and root key available in the region that you want to deploy your VSI instance to.
