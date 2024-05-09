# Updating from v3 to v4.x.x

Version v4.x.x changes the VSI module code in ways that result in significant changes when you update from version 3.x.x to 4.x.x. When you update, the Virtual Server Instances (VSIs) that are managed by this module are deleted and re-created.

:information_source: **Tip:** VSIs in v4.x.x have a new prefix naming convention `prefix- + the last 4 digits of the subnet ID + a sequential number for each subnet`. For example, `prefix-3ad7-00`. When you update, your VSIs will adopt the new prefix.

Follow these steps to update to version 4.x.x and avoid the need to re-create the VSIs.

## Before you begin

Make sure you have recent versions of these command-line prerequisites.

- [IBM Cloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-getting-started)
- [IBM Cloud CLI plug-ins](https://cloud.ibm.com/docs/cli?topic=cli-plug-ins):
    - `is` plug-in (vpc-infrastructure)
    - For IBM Schematics deployments: `sch` plug-in (schematics)
- JSON processor `jq` (https://jqlang.github.io/jq/)
- [Curl](). To test whether curl is installed on your system, run the following command:

    ```sh
    curl -V
    ```

    If you need to install curl, see https://everything.curl.dev/install/index.html.


## Select a procedure

Select the procedure that matches where you deployed the code.

- [Deployed with Schematics](#deployed-with-schematics)
- [Local Terraform](#local-terraform)

## Deployed with Schematics

If you deployed your IBM Cloud infrastructure by using Schematics, the `schematics_update_v3.x.x_to_v4.x.x.sh` script creates a Schematics job. [View the script](schematics_update_v3.x.x_to_v4.x.x.sh).

### Schematics process

1. Set the environment variables:

    1. Set the IBM Cloud API key that has access to your IBM Cloud project or Schematics workspace. Run the following command:

        ```sh
        export IBMCLOUD_API_KEY="<API-KEY>" #pragma: allowlist secret
        ```

        Replace `<API-KEY>` with the value of your API key.

    1. Find your Schematics workspace ID:
        - If you are using IBM Cloud Projects:
            1. Go to [Projects](https://cloud.ibm.com/projects)
            1. Select the project that is associated with your VSI deployment.
            1. Click the **Configurations** tab.
            1. Click the configuration name that is associated with your VSI deployment.
            1. Under **Workspace** copy the ID.

        - If you are not using IBM Cloud Projects:
            1. Go to [Schematics Workspaces](https://cloud.ibm.com/schematics/workspaces)
            1. Select the location that the workspace is in.
            1. Select the workspace associated with your VSI deployment.
            1. Click **Settings**.
            1. Copy the **Workspace ID**.

    1. Run the following command to set the workspace ID as an environment variable:

        ```sh
        export WORKSPACE_ID="<workspace-id>"
        ```

1. Download the script by running this Curl command:

    ```sh
    curl https://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/main/update/schematics_update_v3.x.x_to_v4.x.x.sh > schematics_update_v3.x.x_to_v4.x.x.sh
    ```

1. Use the IBM Cloud console to get the VPC IDs and regions of VPCs that the VSIs are deployed in.

    :information_source: **Tip:** Make sure that you're logged in with the account that owns the VSIs. This account might be different from your projects or Schematics account.

    1. Click the Navigation menu on the left, and then click **VPC Infrastructure** > **VPCs**.
    1. Select the region in which the VPC of the VSI was deployed.
    1. Select the VPC that is associated with the VSI deployment.
    1. Copy the **VPC ID**.
1. Run the script:

    ```sh
    bash schematics_update_v3.x.x_to_v4.x.x.sh -v "<vpc-id1>[,<vpc-id2>,...]" -r "<vpc-region>" [-k "<vpc-ibm-api-key>"]
    ```

    - Replace `<vpc-id1>` and `<vpc-region>` with the information that you copied earlier.
    - If the VSIs are deployed in an account that is different from the account where the Schematics workspace is located, include the `-k` option and replace `<vpc-ibm-api-key>` with the IBM Cloud API key with access to the VPC.

    The script creates a job in the Schematics workspace.

1.  Monitor the status of the job by selecting the workspace from your [Schematics workspaces dashboard](https://cloud.ibm.com/schematics/workspaces).
    - When the job completes successfully, go to the next step.
    - If the job fails, see [Reverting changes](#reverting-changes).

### Apply the changes in Schematics

1. Update your code to consume version 4.x.x, and then update your Schematics workspace to the version of the code that contains the updated module. Click **Generate plan** and make sure none of the VSIs will be re-created.

    You should see in-place updates to names. No resources should be set to be destroyed or re-created.
1. Click **Apply plan**.

    If the job is successful, follow the steps in [Clean up](#clean-up). If the job fails, see [Reverting changes](#reverting-changes).

## Local Terraform

If you store both the Terraform code and state file locally, run the `update_v3.x.x_to_v4.x.x.sh` script locally. [View the script](schematics_update_v3.x.x_to_v4.x.x.sh).

1. Set the IBM Cloud API key that has access to your VPCs as an environment variable by running the following command:

    ```sh
    export IBMCLOUD_API_KEY="<API-KEY>" #pragma: allowlist secret
    ```

    Replace `<API-KEY>` with the value of your API key.

1. Get the VPC IDs and the regions of any VPCs that the VSIs are deployed in

    - Get the VPC IDs from the Terraform output by running the `terraform output` command. Or use the following `jq` command to parse the IDs from the state:

        ```sh
        terraform output -json | jq -r '.. | objects | .value' | jq -r '.. | objects | select(.vpc_id != null) | .vpc_id' | sort -u | xargs
        ```

    - Get the region by running the following `jq` command:

        ```sh
        terraform output -json | jq -r '.. | objects | .value' | jq -r '.. | objects | select(.vpc_id != null) | .zone | select(. != null)' | rev | cut -c3- | rev | sort -u | xargs
        ```

1. Download the script to the directory with the state file by running this Curl command:

    ```sh
    curl https://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/main/update/update_v3.x.x_to_v4.x.x.sh > update_v3.x.x_to_v4.x.x.sh
    ```

1. Run the script from the directory with the state file:

    ```sh
    bash update_v3.x.x_to_v4.x.x.sh -v "<vpc-id-1>[,<vpc-id-2>,..]" -r "<vpc-region>"
    ```

    - Replace `<vpc-id1>` and `<vpc-region>` with the information that you found earlier.

        If the job fails, see [Reverting changes](#reverting-changes).

1. Initialize, check the planned changes, and apply the changes:
    1. Update the version of the module in your consuming code to the 4.x.x version, as in this example:

        ```hcl
        source                           = "terraform-ibm-modules/landing-zone-vsi/ibm"
        version                          = "4.0.0"
        ```

    1. Run the `terraform init` command to pull the latest version.
    1. Run the `terraform plan` command to make sure that none of the VSIs will be re-created.

        - You should see in-place updates to names. No resources should be set to be destroyed or re-created.
        - The name changes include a prefix change: `prefix + the last 4 digits of the subnet ID + a sequential number for each subnet`.

            For example,

            ```sh
            ~ name                             = "prefix-001" -> "prefix-3ad7-001"
            ```

    1. Run `terraform apply` to upgrade to the 4.x.x version of the module and apply the update in place to rename the VSIs.
    1. If the commands are successful, follow the steps in [Clean up](#clean-up).

### Clean up

After you upgrade to the newer release of the VSI module, you can remove the temporary files that are generated by the script by running this command:

```sh
rm moved.json revert.json
```

## Reverting changes

If the script fails, run the script again with the `-z` option to undo the changes. The script uses the `revert.json` file that was created when you ran the script without the `-z` option.

```sh
bash schematics_update_v3.x.x_to_v4.x.x.sh -z
```

- If you ran the job in Schematics, a new workspace job reverts the state to what existed before you ran the script initially.
- If your code and state file are on your computer, the script reverts changes to the local Terraform state file.

:exclamation: **Important:** After you revert the changes, don't run any other steps in this process. Create an IBM Cloud support case and include information about the script and errors. For more information, see [Creating support cases](https://cloud.ibm.com/docs/get-support?topic=get-support-open-case&interface=ui).
