# Add a VSI to a landing zone VPC

This logic creates a VSI to an existing landing zone VPC.

## Infrastructure

This code creates and configures the following infrastructure:
- A new public SSH key, if one is not passed in.
- A VSI in each subnet of the landing zone VPC.
