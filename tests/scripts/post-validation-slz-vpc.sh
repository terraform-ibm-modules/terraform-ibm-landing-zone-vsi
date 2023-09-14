#! /bin/bash

########################################################################################################################
## This script is used by the catalog pipeline to deploy SLZ VPC, which is a prerequisite for the client to site      ##
## landing zone extension that is published to catalog                                                                ##
########################################################################################################################

set -e

# Paths relative to base directory of script
BASE_DIR=$(dirname "$0")
TERRAFORM_SOURCE_DIR="../resources"
TF_VARS_FILE="terraform.tfvars"

(
  # Execute script from base directory
  cd "${BASE_DIR}"
  echo "Destroying prerequisite SLZ VPC .."

  cd ${TERRAFORM_SOURCE_DIR}
  terraform destroy -input=false -auto-approve -var-file=${TF_VARS_FILE} || exit 1

  echo "Post-validation complete successfully"
)
