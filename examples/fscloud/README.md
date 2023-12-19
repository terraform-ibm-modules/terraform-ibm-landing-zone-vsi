# Financial Services Cloud profile example

An end-to-end example that uses the [Profile for IBM Cloud Framework for Financial Services](https://github.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/tree/main/modules/fscloud) to deploy a VSI.

The example uses the IBM Cloud Terraform provider to create the following infrastructure:
* A resource group, if one is not passed in.
* An SSH Key, if one is not passed in.
* A Secure Landing Zone virtual private cloud (VPC).
* An IBM Cloud VSI instance with Hyper Protect Crypto Services root key that is passed in for encrypting block storage.
* Additional data volumes on each VSI

:exclamation: **Important:** In this example, only the VSI instance complies with the IBM Cloud Framework for Financial Services. Other parts of the infrastructure do not necessarily comply.

## Before you begin

- You need a Hyper Protect Crypto Services instance and root key available in the region that you want to deploy your VSI instance to.
