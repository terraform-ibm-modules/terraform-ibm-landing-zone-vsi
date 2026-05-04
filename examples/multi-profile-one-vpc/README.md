# Example demonstrating the deployment of different sets of VSIs (with different machine types) to the same VPC and subnets, empoying two calls to the module.

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<p>
  <a href="https://cloud.ibm.com/schematics/workspaces/create?workspace_name=landing-zone-vsi-multi-profile-one-vpc-example&repository=https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/examples/multi-profile-one-vpc">
    <img src="https://img.shields.io/badge/Deploy%20with%20IBM%20Cloud%20Schematics-0f62fe?style=flat&logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics">
  </a><br>
  ℹ️ Ctrl/Cmd+Click or right-click on the Schematics deploy button to open in a new tab.
</p>
<!-- END SCHEMATICS DEPLOY HOOK -->

It will provision the following:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets.
- Two sets of virtual servers, one set with `cx` machine type, one set with `bx`, deployed to the same VPC and subnets
- Each of the virtual server sets will deploy the following:
    - A VSI in each subnet.
    - A managed reserved IP for each virtual server created.
    - A floating IP for each virtual server created.
    - A secondary VSI with secondary subnets and secondary security group.
    - A new Application Load Balancer and Network Load Balancer to balance traffic between all virtual servers that are created by this example.
