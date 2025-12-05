# Basic example using a Snapshot Consistency Group for volumes

An end-to-end basic example that will provision the following, using previously created snapshots for storage volumes:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets
- A VSI in each subnet
- Two additional block storage attached to each VSI
- Reserved and Floating IPs managed by Terraform for each VSI
- Boot volume and additional storage volumes will be based on snapshots from consistency group, if ID is supplied

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<a href="https://cloud.ibm.com/login?redirect=https%3A%2F%2Fcloud.ibm.com%2Fschematics%2Fworkspaces%2Fcreate%3Fworkspace_name%3Dlanding-zone-vsi-snapshot-example%26repository%3Dhttps%3A%2F%2Fgithub.com%2Fterraform-ibm-modules%2Fterraform-ibm-landing-zone-vsi%2Ftree%2Fmain%2Fexamples%2Fsnapshot"><img src="https://img.shields.io/badge/Deploy%20with IBM%20Cloud%20Schematics-0f62fe?logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics" style="height: 16px; vertical-align: text-bottom;"></a>

:exclamation: Ctrl/Cmd+Click or right-click to open deploy button in a new tab
<!-- END SCHEMATICS DEPLOY HOOK -->
