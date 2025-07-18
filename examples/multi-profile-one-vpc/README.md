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
