# Complete Example using a placement group, attaching a load balancer, and adding additional data volumes

It will provision the following:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets.
- A new placement group.
- A VSI in each subnet placed in the placement group.
- A new Application Load Balancer to balance traffic between all virtual servers that are created by this example.
