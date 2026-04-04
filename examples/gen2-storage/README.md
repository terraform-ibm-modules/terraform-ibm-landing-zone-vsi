# End to end basic example using gen2 boot volume

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<p>
  <a href="https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-gen2-storage-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/gen2-storage">
    <img src="https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics">
  </a><br>
  ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
</p>
<!-- END SCHEMATICS DEPLOY HOOK -->

An end-to-end basic example that provisions the virtual instance with a Gen2 (sdp) boot volume:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets
- A new placement group
- A VSI in each subnet
- VSI uses a Gen2 boot volume
