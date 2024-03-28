# Updating from v3.x.x to v4.x.x

Starting from version v4.x.x, we have refactored the code for the VSI module, resulting in a significant change when transitioning from version 3.x.x to 4.x.x. This means that the Virtual Server Instances (VSIs) managed by this module will be deleted and recreated during the update process.

By employing the suggested method, you can avoid the need for VSI recreation.

- [Schematics](#schematics)
- [Local Terraform State file](#local)

## Schematics
{: #schematics}

If you have your cloud infrastructure deployed using Schematics, you can use the  `schematics_update_v3.x.x_to_v4.x.x.sh` script to avoid the recreation of Virtual Server Instances (VSIs).

1. Make sure you have all the dependencies to run the script.
    - IBM Cloud CLI
    - IBM Cloud CLI 'is' plugin
    - IBM Cloud CLI 'schematics' plugin
    - Terraform CLI
    - jq
    - readarray

2. Set the `IBMCLOUD_API_KEY`, `WORKSPACE_ID` variables as an environment variable.

3. Retrive the VPC IDs of the VPC on which all the VSIs are deployed, including the region of VPC.

4. Run the script from any local machine
```sh
bash schematics_update_v3.x.x_to_v4.x.x.sh -v "<vpc-id1>,[<vpc-id2>,...]" -r "<vpc-region>"
```
This script will trigger a new job in the schematics workspace, please monitor the state of the job in IBM Cloud UI.

5. Now pull in the latest release in Schematics and click on `Generate plan` and make sure none of the VSIs will be recreated.

6. Click on `Apply plan`.

7. [Optional] If a schematics workspace job that was initiated through the script encounters an issue, you can undo any modifications made by running the script again with the -z flag. For example,
```sh
bash schematics_update_v3.x.x_to_v4.x.x.sh -z
```
A new schematics workspace job reverting the state back to its prior condition, which existed prior to the execution of the script.

## Local Terraform State file
{: #local}

If you have both the code and the Terraform state file stored locally on your machine, you can utilize the update_v3.x.x_to_v4.x.x.sh script to avoid the recreation of Virtual Server Instances (VSIs).

1. Make sure you have all the dependencies to run the script.
    - IBM Cloud CLI
    - IBM Cloud CLI 'is' plugin
    - Terraform CLI
    - jq
    - readarray

2. Set the `IBMCLOUD_API_KEY` variable as an environment variable.

3. Retrive the VPC IDs of the VPC on which all the VSIs are deployed, including the region of VPC.

4. Run the script
```sh
bash update_v3.x.x_to_v4.x.x.sh -v "<vpc-id1>,[<vpc-id2>,...]" -r "<vpc-region>"
```

5. Now pull in the latest release and run `terraform plan` and make sure none of the VSIs will be recreated.

6. Run `terraform apply`.

7. [Optional] If an issue occurs during the Terraform state migration, you can undo the modifications made by the script by running it again with the -z option. For example,
```sh
bash update_v3.x.x_to_v4.x.x.sh -z
```
Reverting the Terraform state file back to its prior condition, which existed prior to the execution of the script.
