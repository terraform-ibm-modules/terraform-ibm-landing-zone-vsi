# Basic example using a Snapshot Consistency Group for volumes

An end-to-end basic example that will provision the following, using previously created snapshots for storage volumes:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets
- A VSI in each subnet
- Two additional block storage attached to each VSI
- Reserved and Floating IPs managed by Terraform for each VSI
- Boot volume and additional storage volumes will be based on snapshots from consistency group, if ID is supplied
