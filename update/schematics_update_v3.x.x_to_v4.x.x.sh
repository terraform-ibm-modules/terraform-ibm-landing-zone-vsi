#!/usr/bin/env bash

PRG=$(basename -- "${0}")
USAGE="
usage: ./${PRG}
    Required environment variables:
    IBMCLOUD_API_KEY
    WORKSPACE_ID
    WORKSPACE_REGION
    Dependencies:
    - IBM Cloud CLI
    - IBM Cloud CLI 'is' plugin
    - Terraform CLI
    - jq
    - readarray
"
VOL_RESOURCES=""
VOL_NAMES=""

helpFunction() {
    echo ""
    echo "Usage: $0 -v VPC_ID -r VPC_REGION"
    echo -e "\t-v ID or name of the VPC in which the VSIs are deployed which needs to be tracked by the newer version of the terraform module."
    echo -e "\t-r Region of the VPC."
    exit 1 # Exit script after printing help
}

while getopts "v:r:" opt; do
    case "$opt" in
    v) VPC_ID="$OPTARG" ;;
    r) VPC_REGION="$OPTARG" ;;
    ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

# Print helpFunction in case parameters are empty
if [ -z "$VPC_ID" ] || [ -z "$VPC_REGION" ]; then
    echo "VPC_ID or REGION is empty"
    helpFunction
fi

# check that env contains required vars
function verify_required_env_var() {
    printf "\n#### VERIFYING ENV ####\n\n"
    all_env_vars_exist=true
    env_var_array=(IBMCLOUD_API_KEY WORKSPACE_ID WORKSPACE_REGION)
    set +u
    for var in "${env_var_array[@]}"; do
        [ -z "${!var}" ] && echo "${var} not defined." && all_env_vars_exist=false
    done
    set -u
    if [ ${all_env_vars_exist} == false ]; then
        echo "One or more required environment variables are not defined. Exiting."
        echo "${USAGE}"
        exit 1
    fi
}

# Login to IBM Cloud using IBMCLOUD_API_KEY env var value
function ibmcloud_login() {
    printf "\n#### IBM CLOUD LOGIN ####\n\n"
    attempts=1
    until ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$VPC_REGION" || [ $attempts -ge 3 ]; do
        attempts=$((attempts + 1))
        echo "Error logging in to IBM Cloud CLI..."
        sleep 3
    done
}

function get_vpc_details() {
    VPC_DATA=$(ibmcloud is vpc "$VPC_ID" --output JSON --show-attached -q)
}

function get_workspace_details() {
    until ibmcloud target -r "$WORKSPACE_REGION" || [ $attempts -ge 3 ]; do
        attempts=$((attempts + 1))
        echo "Error logging in to IBM Cloud CLI..."
        sleep 3
    done
    template_id="$(ibmcloud schematics workspace get --id "$WORKSPACE_ID" -o json | jq -r .template_data[0].id)"
    OUTPUT="$(ibmcloud schematics state pull --id "$WORKSPACE_ID" --template "$template_id")"
    STATE=${OUTPUT//'OK'/}
}

function update_state() {
    readarray -t ADDRESS_LIST <<<"$(echo "$STATE" | jq -r '.resources[] | select(.type == "ibm_is_instance") | .module')"
    readarray -t SUBNET_LIST <<<"$(echo "$VPC_DATA" | jq -r '.subnets[] | .id')"

    for i in "${!SUBNET_LIST[@]}"; do
        for j in "${!ADDRESS_LIST[@]}"; do
            VSI_RESOURCES="$(echo "$STATE" | jq -r --arg address "${ADDRESS_LIST[$j]}" '.resources[] | select((.type == "ibm_is_instance") and (.module == $address)) | .instances')"
            subnet_name=$(echo "$VPC_DATA" | jq -r --arg subnet_id "${SUBNET_LIST[$i]}" '.subnets[] | select(.id == $subnet_id) | .name')
            vsi_names=$(echo "$VSI_RESOURCES" | jq -r --arg subnet_id "${SUBNET_LIST[$i]}" '.[] | select(.attributes.primary_network_interface[0].subnet == $subnet_id) | .index_key')
            readarray -t VSI_LIST <<<"$vsi_names"

            for x in "${!VSI_LIST[@]}"; do
                SOURCE="${ADDRESS_LIST[$j]}.ibm_is_instance.vsi[\"${VSI_LIST[$x]}\"]"
                DESTINATION="${ADDRESS_LIST[$j]}.ibm_is_instance.vsi[\"${subnet_name}-${x}\"]"

                if [ -n "${VSI_LIST[$x]}" ] && [ -n "${subnet_name}" ]; then
                    update_schematics "$SOURCE" "$DESTINATION"
                fi
                if [ -n "${VSI_LIST[$x]}" ]; then
                    VOL_NAMES=$(echo "$VSI_RESOURCES" | jq -r --arg vsi "${VSI_LIST[$x]}" '.[] | select(.index_key == $vsi) | .attributes.volume_attachments[].volume_name')

                fi
                str="${VSI_LIST[$x]}"
                lastIndex=$(echo "$str" | awk '{print length}')
                for ((l = lastIndex; l >= 0; l--)); do
                    if [[ "${str:$l:1}" == "-" ]]; then
                        str="${str::l}"
                        break
                    fi
                done
                if [ -n "$VOL_NAMES" ]; then
                    readarray -t VOL_ADDRESS_LIST <<<"$(echo "$STATE" | jq -r '.resources[] | select(.type == "ibm_is_volume") | .module')"
                    readarray -t VOL_NAME <<<"$VOL_NAMES"
                    for a in "${!VOL_NAME[@]}"; do
                        for b in "${!VOL_ADDRESS_LIST[@]}"; do
                            VOL_RESOURCES="$(echo "$STATE" | jq -r --arg address "${VOL_ADDRESS_LIST[$b]}" '.resources[] | select((.type == "ibm_is_volume") and (.module == $address)) | .instances')"
                            vol_names=$(echo "$VOL_RESOURCES" | jq -r --arg vol1 "${VOL_NAME[$a]}" '.[] | select(.attributes.name == $vol1) | .index_key')
                            readarray -t VOL_LIST <<<"$vol_names"
                            for c in "${!VOL_LIST[@]}"; do
                                if [ -n "${VOL_LIST[$c]}" ]; then
                                    VOL_SOURCE="${ADDRESS_LIST[$j]}.ibm_is_volume.volume[\"${VOL_LIST[$c]}\"]"
                                    test="${VOL_LIST[$c]/$str/}"
                                    vol=$(echo "$test" | cut -d"-" -f3-)
                                    VOL_DESTINATION="${ADDRESS_LIST[$j]}.ibm_is_volume.volume[\"${subnet_name}-${x}-${vol}\"]"
                                    if [ -n "${VOL_LIST[$c]}" ] || [ -n "${subnet_name}" ]; then
                                        update_schematics "$VOL_SOURCE" "$VOL_DESTINATION"
                                    fi
                                fi
                            done
                        done
                    done
                fi
            done
        done
    done

}

function update_schematics() {
    echo "ibmcloud schematics workspace state mv --id \"$WORKSPACE_ID\" --source \"$1\" --destination \"$2\""
    ibmcloud schematics workspace state mv --id "$WORKSPACE_ID" --source "$1" --destination "$2"
    sleep 60
    while true; do
        status=$(ibmcloud schematics workspace get --id "$WORKSPACE_ID" -o json | jq -r .status)
        echo "$status"
        if [[ "$status" == "ACTIVE" ]]; then
            echo "Change Done"
            break
        elif [[ "$status" == "FAILED" ]]; then
            echo "ERROR::Unfortunately, the Schematics workspace is in a FAILED state. Please review the workspace and try running the following command manually:"
            echo "ibmcloud schematics workspace state mv --id \"$WORKSPACE_ID\" --source \"$1\" --destination \"$2\""
            break
        fi
        sleep 10
        status=""
    done
}

# run
function main() {
    verify_required_env_var
    ibmcloud_login
    get_vpc_details
    get_workspace_details
    update_state
}

main
