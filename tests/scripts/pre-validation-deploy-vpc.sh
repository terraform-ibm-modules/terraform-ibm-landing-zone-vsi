#! /bin/bash

############################################################################################################
## This script is used by the catalog pipeline to deploy the VPC
## which are the prerequisites for the fully-configurable vsi
############################################################################################################

set -e

DA_DIR="solutions/fully-configurable"
TERRAFORM_SOURCE_DIR="tests/resources/existing-resources"
JSON_FILE="${DA_DIR}/catalogValidationValues.json"
REGION="us-south"
TF_VARS_FILE="terraform.tfvars"

(
  cwd=$(pwd)
  cd ${TERRAFORM_SOURCE_DIR}
  echo "Provisioning prerequisite COS instance and VPC .."
  terraform init || exit 1
  # $VALIDATION_APIKEY is available in the catalog runtime
  {
    echo "ibmcloud_api_key=\"${VALIDATION_APIKEY}\""
    echo "region=\"${REGION}\""
    echo "prefix=\"vsi-$(openssl rand -hex 2)\""
  } >> ${TF_VARS_FILE}
  terraform apply -input=false -auto-approve -var-file=${TF_VARS_FILE} || exit 1

  region_var_name="region"

  existing_resource_group_name="existing_resource_group_name"
  existing_resource_group_value=$(terraform output -state=terraform.tfstate -raw resource_group_name)
  existing_vpc_name="existing_vpc_id"
  existing_vpc_value=$(terraform output -state=terraform.tfstate -raw vpc_id)

  echo "Appending '${existing_resource_group_name}' and '${existing_vpc_name}'  input variable values to ${JSON_FILE}.."

  cd "${cwd}"
  jq -r --arg region_var_name "${region_var_name}" \
        --arg region_var_value "${REGION}" \
        --arg existing_resource_group_name "${existing_resource_group_name}" \
        --arg existing_resource_group_value "${existing_resource_group_value}" \
        --arg existing_vpc_name "${existing_vpc_name}" \
        --arg existing_vpc_value "${existing_vpc_value}" \
        '. + {($region_var_name): $region_var_value, ($existing_resource_group_name): $existing_resource_group_value, ($existing_vpc_name): $existing_vpc_value}' "${JSON_FILE}" > tmpfile && mv tmpfile "${JSON_FILE}" || exit 1

  echo "Pre-validation complete successfully"
)
