# Complete Example using a placement group, attaching a load balancer, creating secondary interface, and adding additional data volumes

It will provision the following:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets.
- A new dedicated host and a host group.
- A VSI on supported zone will be placed on the dedicated host.
- A floating IP for each virtual server created.
- A secondary VSI with secondary subnets and secondary security group.
