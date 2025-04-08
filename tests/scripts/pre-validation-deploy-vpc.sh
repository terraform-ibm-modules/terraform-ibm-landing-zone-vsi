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
  echo "Provisioning prerequisite secret manager instance and VPC .."
  terraform init || exit 1
  # $VALIDATION_APIKEY is available in the catalog runtime
  {
    echo "ibmcloud_api_key=\"${VALIDATION_APIKEY}\""
    echo "region=\"${REGION}\""
    echo "prefix=\"vsi-$(openssl rand -hex 2)\""
  } >>${TF_VARS_FILE}
  terraform apply -input=false -auto-approve -var-file=${TF_VARS_FILE} || exit 1

  existing_resource_group_name="existing_resource_group_name"
  existing_resource_group_value=$(terraform output -state=terraform.tfstate -raw resource_group_name)
  existing_vpc_name="existing_vpc_crn"
  existing_vpc_value=$(terraform output -state=terraform.tfstate -raw vpc_crn)
  existing_subnet_name="existing_subnet_id"
  existing_subnet_value=$(terraform output -state=terraform.tfstate -raw subnet_id)
  existing_image_name="image_id"
  existing_image_value=$(terraform output -state=terraform.tfstate -raw image_id)
  existing_sm_name="existing_secrets_manager_instance_crn"
  existing_sm_value=$(terraform output -state=terraform.tfstate -raw secret_manager_crn)

  echo "Appending '${existing_resource_group_name}' and '${existing_vpc_name}' input variable values to ${JSON_FILE}.."

  cd "${cwd}"
  jq -r --arg existing_resource_group_name "${existing_resource_group_name}" \
    --arg existing_resource_group_value "${existing_resource_group_value}" \
    --arg existing_vpc_name "${existing_vpc_name}" \
    --arg existing_vpc_value "${existing_vpc_value}" \
    --arg existing_subnet_name "${existing_subnet_name}" \
    --arg existing_subnet_value "${existing_subnet_value}" \
    --arg existing_image_name "${existing_image_name}" \
    --arg existing_image_value "${existing_image_value}" \
    --arg existing_sm_name "${existing_sm_name}" \
    --arg existing_sm_value "${existing_sm_value}" \
    '. + {($existing_resource_group_name): $existing_resource_group_value, ($existing_vpc_name): $existing_vpc_value, ($existing_subnet_name): $existing_subnet_value, ($existing_image_name): $existing_image_value, ($existing_sm_name): $existing_sm_value}' "${JSON_FILE}" >tmpfile && mv tmpfile "${JSON_FILE}" || exit 1

  echo "Pre-validation complete successfully"
)
