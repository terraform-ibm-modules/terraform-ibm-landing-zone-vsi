# Updating from v3.x.x to v4.x.x

Starting from version v4.x.x, we have restructured the code for the VSI module, resulting in a significant change when transitioning from version 3.x.x to 4.x.x. This means that the Virtual Server Instances (VSIs) managed by this module will be deleted and recreated during the update process.

By employing the suggested method, you can avoid the need for VSI recreation.

- [Terraform CLI](#terraform-cli)
- [Schematics](#schematics)

## Terraform CLI
{: #terraform-cli}

If you have both the code and the Terraform state file stored locally on your machine, you can utilize the update_v3.x.x_to_v4.x.x.sh script to avoid the recreation of Virtual Server Instances (VSIs).

1. Make sure you have all the dependencies to run the script.
    - IBM Cloud CLI
    - IBM Cloud CLI 'is' plugin
    - Terraform CLI
    - jq
    - readarray

2. Set the `IBMCLOUD_API_KEY` variable as an environment variable.

3. Retrive the VPC ID of the VPC on which all the VSIs are deployed, including the region of VPC.

4. Run the script
```sh
bash update_v3.x.x_to_v4.x.x.sh -v "<vpc-id>" -r "<vpc-region>"
```

5. Now pull in the latest update and run `terraform plan` and make sure none of the VSIs will be recreated.

6. Run `terraform apply`.

## Schematics
{: #schematics}

If you have your cloud infrastructure deployed using Schematics, you can use the  `schematics_update_v3.x.x_to_v4.x.x.sh` script to avoid the recreation of Virtual Server Instances (VSIs).

1. Make sure you have all the dependencies to run the script.
    - IBM Cloud CLI
    - IBM Cloud CLI 'is' plugin
    - Terraform CLI
    - jq
    - readarray

2. Set the `IBMCLOUD_API_KEY`, `WORKSPACE_ID`, `WORKSPACE_REGION` variables as an environment variable.

3. Retrive the VPC ID of the VPC on which all the VSIs are deployed, including the region of VPC.

4. Run the script from any local machine
```sh
bash schematics_update_v3.x.x_to_v4.x.x.sh -v "<vpc-id>" -r "<vpc-region>"
```

5. Now pull in the latest update in Schematics and click on `Generate plan` and make sure none of the VSIs will be recreated.

6. Click on `Apply plan`.