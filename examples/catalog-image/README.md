# End to end basic example using catalog image

An end-to-end basic example that provisions the virtual instance with an image from a catalog offering:

- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A new VPC with 3 subnets
- A new placement group
- A VSI in each subnet
- VSI uses a catalog offering image
