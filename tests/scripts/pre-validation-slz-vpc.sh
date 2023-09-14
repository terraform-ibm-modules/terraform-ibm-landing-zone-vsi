#! /bin/bash

########################################################################################################################
## This script is used by the catalog pipeline to destroy the SLZ VPC, which is a prerequisite for the client to site ##
## landing zone extension, after catalog validation has complete.                                                     ##
########################################################################################################################

set -e

# Paths relative to base directory of script
BASE_DIR=$(dirname "$0")
TERRAFORM_SOURCE_DIR="../resources"
JSON_FILE="../../../catalogValidationValues.json"
REGION="us-south"
TF_VARS_FILE="terraform.tfvars"

(
  # Execute script from base directory
  cd "${BASE_DIR}"
  echo "Provisioning prerequisite SLZ VPC .."

  cd ${TERRAFORM_SOURCE_DIR}
  terraform init || exit 1
  echo "ibmcloud_api_key=\"${VALIDATION_APIKEY}\"" > ${TF_VARS_FILE}
  echo "prefix=\"c2s-slz-$(openssl rand -hex 2)\"" >> ${TF_VARS_FILE}
  echo "region=\"${REGION}\"" >> ${TF_VARS_FILE}
  terraform apply -input=false -auto-approve -var-file=${TF_VARS_FILE} || exit 1

  prefix_var_name="landing_zone_prefix"
  prefix_var_value=$(terraform output -state=terraform.tfstate -raw prefix)
  rg_var_name="resource_group"
  rg_var_value="${prefix_var_value}-management-rg"
  echo "Appending '${prefix_var_name}' and '${rg_var_name}' input variable values to $(basename ${JSON_FILE}).."
  jq -r --arg prefix_var_name "${prefix_var_name}" --arg prefix_var_value "${prefix_var_value}" --arg rg_var_name "${rg_var_name}" --arg rg_var_value "${rg_var_value}" --arg region "${REGION}" '. + {($prefix_var_name): $prefix_var_value, ($rg_var_name): $rg_var_value, "prefix": $prefix_var_value, "region": $region}' "${JSON_FILE}" > tmpfile && mv tmpfile "${JSON_FILE}" || exit 1

  echo "Pre-validation complete successfully"
)
