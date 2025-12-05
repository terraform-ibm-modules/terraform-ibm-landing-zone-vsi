# Example demonstrating the deployment of different sets of VSIs (with different machine types) to the same VPC and subnets, empoying two calls to the module.

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

<!-- BEGIN SCHEMATICS DEPLOY HOOK -->
<a href="https://cloud.ibm.com/login?redirect=https%3A%2F%2Fcloud.ibm.com%2Fschematics%2Fworkspaces%2Fcreate%3Fworkspace_name%3Dlanding-zone-vsi-multi-profile-one-vpc-example%26repository%3Dhttps%3A%2F%2Fgithub.com%2Fterraform-ibm-modules%2Fterraform-ibm-landing-zone-vsi%2Ftree%2Fmain%2Fexamples%2Fmulti-profile-one-vpc"><img src="https://img.shields.io/badge/Deploy%20with IBM%20Cloud%20Schematics-0f62fe?logo=ibm&logoColor=white&labelColor=0f62fe" alt="Deploy with IBM Cloud Schematics" style="height: 16px; vertical-align: text-bottom;"></a>

:exclamation: Ctrl/Cmd+Click or right-click to open deploy button in a new tab
<!-- END SCHEMATICS DEPLOY HOOK -->
