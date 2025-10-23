# End to end basic example using gen2 boot volume

An end-to-end basic example that provisions the virtual instance with a Gen2 (sdp) boot volume:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets
- A new placement group
- A VSI in each subnet
- VSI uses a Gen2 boot volume
