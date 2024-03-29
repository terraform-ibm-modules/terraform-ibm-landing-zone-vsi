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

1. Set the `IBMCLOUD_API_KEY`, `WORKSPACE_ID` variables as an environment variable.
    1. IBMCLOUD_API_KEY : This is an IBM Cloud API key, which can be used for accessing the Projects/Schematics Workspace. For more information, see https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui
    ```sh
        export IBMCLOUD_API_KEY="<API-KEY>" #pragma: allowlist secret
    ```

    1. Get Workspace ID from Schematics Workspace:
        - In the {{site.data.keyword.cloud_notm}} console, click the **Navigation menu** icon ![Navigation menu icon](../icons/icon_hamburger.svg "Menu"), and then click **Schematics** > **Workspaces**.
        - Select the workspace associated with your vsi deployment.
        - Click **Settings** on the left hand side Menu.
        - Copy **Workspace ID** from the Details tab.
    1. Get Workspace ID from Projects:
        - In the {{site.data.keyword.cloud_notm}} console, click the **Navigation menu** icon ![Navigation menu icon](../icons/icon_hamburger.svg "Menu"), and then click **Projects**.
        - Select the Project associated with your VSI deployment.
        - Click on the **Configurations** tab.
        - Select the configuration associated with your VSI deployment.
        - You can find the **Workspace** ID of the Project towards the right-hand side of the screen.
        - Click on copy button to copy the Workspace ID.
    ```sh
        export WORKSPACE_ID="<workspace-id>"
    ```

1. Retrive the VPC IDs of the VPC on which all the VSIs are deployed, including the region of VPC.
    1. Get VPC ID from Schematics Workspace:
        - In the {{site.data.keyword.cloud_notm}} console, click the **Navigation menu** icon ![Navigation menu icon](../icons/icon_hamburger.svg "Menu"), and then click **VPC Infrastructure** > **VPCs**.
        - Select the region in which the VPC of the VSI was deployed.
        - Select the VPC associated with the VSI deployment.
        - Copy the **VPC ID** from the Overview tab.
    1. Get VPC ID from Projects:
        - In the {{site.data.keyword.cloud_notm}} console, click the **Navigation menu** icon ![Navigation menu icon](../icons/icon_hamburger.svg "Menu"), and then click **Projects**.
        - Select the Project associated with your VSI deployment.
        - Click on the **Configurations** tab.
        - Select the configuration associated with your VSI deployment.
        - In the **Outputs** tab you can find an output labeled **vpc_data**.
        - Clicking on it will open a json of all the VPC data of the VPCs provisioned.
        - Copy the VPC IDs from the **vpc_data** json.

1. [Optional] If the VSIs are being deployed in an account that is different from the account where the Schematics Workspace are located, you need to provide an IBM Cloud API key, which can be used for fetching the VPC details. In this case, you can pass the VPC API-KEY to the script using `-k` flag. For more information, see https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui

1. Run the script from any local machine
```sh
bash schematics_update_v3.x.x_to_v4.x.x.sh -v "<vpc-id1>,[<vpc-id2>,...]" -r "<vpc-region> [-k <vpc-ibm-api-key>]"
```
This script will trigger a new job in the schematics workspace, please monitor the state of the job in IBM Cloud UI. Check if the job completes **Successfully**, in that case go ahead with **Step 5**. In case of schematics workspace job ends in a failed state, please follow **Step 7** to revert any changes made by the script.

1. Now pull in the latest release in Schematics and click on `Generate plan` and make sure none of the VSIs will be recreated.

1. Click on `Apply plan`.

1. [Optional] If a schematics workspace job that was initiated through the script encounters an issue, you can undo any modifications made by running the script again with the -z flag. For example,
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

1. Set the `IBMCLOUD_API_KEY` variable as an environment variable.
    1. IBMCLOUD_API_KEY : This is an IBM Cloud API key, which can be used for accessing the Projects/Schematics Workspace. For more information, see https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui
    ```sh
        export IBMCLOUD_API_KEY="<API-KEY>" #pragma: allowlist secret
    ```

1. Retrive the VPC IDs of the VPC on which all the VSIs are deployed, including the region of VPC.
    1. VPC ID can be retrieved from the terraform output by running `terraform output`.

1. Run the script
```sh
bash update_v3.x.x_to_v4.x.x.sh -v "<vpc-id1>,[<vpc-id2>,...]" -r "<vpc-region>"
```

1. Now pull in the latest release and run `terraform plan` and make sure none of the VSIs will be recreated.

1. Run `terraform apply`.

1. [Optional] If an issue occurs during the Terraform state migration, you can undo the modifications made by the script by running it again with the -z option. For example,
```sh
bash update_v3.x.x_to_v4.x.x.sh -z
```
Reverting the Terraform state file back to its prior condition, which existed prior to the execution of the script.
