# VSI add-on for landing-zone

A module creating a VSI in an existing landing zone VPC.

## Infrastructure

This module creates and configures the following infrastructure:
- A new resource group if one is not passed in.
- A new public SSH key if one is not passed in.
- A VSI in each subnet of the landing zone VPC.

## Usage

Here is an example creating a VSI in a VPC with id `r018-dd5f14c5-2211-43c8-85d9-71b6d051de51` (replace with the id of the landing-zone VPC).

Note: the users must already be member of the IBM Cloud account.

```console
terraform init
export TF_VAR_ibmcloud_api_key=<your IBM Cloud API Key> # pragma: allowlist secret
terraform plan -var=region=eu-gb -var=vpc_id=r018-dd5f14c5-2211-43c8-85d9-71b6d051de51 -var=existing_kms_instance_guid=9549bd7c-a6d7-2875-8f4c-d2ef97b5483d -var=boot_volume_encryption_key=<key-crn>
terraform apply -var=region=eu-gb -var=vpc_id=r018-dd5f14c5-2211-43c8-85d9-71b6d051de51 -var=existing_kms_instance_guid=9549bd7c-a6d7-2875-8f4c-d2ef97b5483d -var=boot_volume_encryption_key=<key-crn>
```