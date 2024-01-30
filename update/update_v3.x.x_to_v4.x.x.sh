#!/usr/bin/env bash

PRG=$(basename -- "${0}")
USAGE="
usage: ./${PRG}
    Required environment variables:
    IBMCLOUD_API_KEY
    Dependencies:
    - IBM Cloud CLI
    - IBM Cloud CLI 'is' plugin
    - Terraform CLI
    - jq
    - readarray
"

STATE_LOCATION=""
VOL_RESOURCES=""

helpFunction() {
    echo ""
    echo "Usage: $0 -v VPC_ID -r REGION -t STATE_LOCATION"
    echo -e "\t-v ID or name of the VPC in which the VSIs are deployed which needs to be tracked by the newer version of the terraform module."
    echo -e "\t-r Region of the VPC."
    echo -e "\t-t Path of the terrafom state file. If no path is specified, the current state will be shown."
    exit 1 # Exit script after printing help
}

while getopts "v:r:t:" opt; do
    case "$opt" in
    v) VPC_ID="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    t) STATE_LOCATION="$OPTARG" ;;
    ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

# Print helpFunction in case parameters are empty
if [ -z "$VPC_ID" ] || [ -z "$REGION" ]; then
    echo "VPC_ID or REGION is empty"
    helpFunction
fi

# check that env contains required vars
function verify_required_env_var() {
    printf "\n#### VERIFYING ENV ####\n\n"
    all_env_vars_exist=true
    env_var_array=(IBMCLOUD_API_KEY)
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
    until ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$REGION" || [ $attempts -ge 3 ]; do
        attempts=$((attempts + 1))
        echo "Error logging in to IBM Cloud CLI..."
        sleep 3
    done
}

function get_details() {
    VPC_DATA=$(ibmcloud is vpc "$VPC_ID" --output JSON --show-attached -q)
    if [ -z "$STATE_LOCATION" ]; then
        STATE=$(terraform show -json)
    else
        STATE=$(terraform show -json "$STATE_LOCATION")
    fi
}

function update_state() {
    readarray -t SUBNET_LIST <<<"$(echo "$VPC_DATA" | jq -r '.subnets[] | .id')"

    for i in "${!SUBNET_LIST[@]}"; do
        subnet_name=$(echo "$VPC_DATA" | jq -r --arg subnet_id "${SUBNET_LIST[$i]}" '.subnets[] | select(.id == $subnet_id) | .name')
        vsi_names=$(echo "$STATE" | jq -r --arg subnet "${SUBNET_LIST[$i]}" '.. | objects | select((.values.primary_network_interface[0].subnet == $subnet) and (.type == "ibm_is_instance")) | .index')

        readarray -t VSI_LIST <<<"$vsi_names"

        for j in "${!VSI_LIST[@]}"; do
            SOURCE=$(echo "$STATE" | jq -r --arg vsi "${VSI_LIST[$j]}" '.. | objects | select((.index == $vsi) and (.type == "ibm_is_instance")) | .address')
            DESTINATION=${SOURCE//"${VSI_LIST[$j]}"/"${subnet_name}-${j}"}

            if [ -n "$SOURCE" ] || [ -n "$DESTINATION" ]; then
                echo "terraform state mv \"$SOURCE\" \"$DESTINATION\""
                terraform state mv "$SOURCE" "$DESTINATION"
            fi
            if [ -n "${VSI_LIST[$j]}" ]; then
                VOL_RESOURCES=$(echo "$STATE" | jq -r --arg vsi "${VSI_LIST[$j]}" '.. | objects | select((.index == $vsi) and (.type == "ibm_is_instance")) | .values.volume_attachments[].volume_name')
            fi

            if [ -n "$VOL_RESOURCES" ]; then
                str="${VSI_LIST[$j]}"
                lastIndex=$(echo "$str" | awk '{print length}')
                for ((l = lastIndex; l >= 0; l--)); do
                    if [[ "${str:$l:1}" == "-" ]]; then
                        str="${str::l}"
                        break
                    fi
                done

                readarray -t VOL_LIST <<<"$VOL_RESOURCES"
                for x in "${!VOL_LIST[@]}"; do
                    VOL_SOURCE=$(echo "$STATE" | jq -r --arg index "${VOL_LIST[$x]}" '.. | objects | select((.values.name == $index) and (.type == "ibm_is_volume")) | .address')

                    if [ -n "$VOL_SOURCE" ]; then
                        VOL_INDEX=$(echo "$STATE" | jq -r --arg index "${VOL_LIST[$x]}" '.. | objects | select((.values.name == $index) and (.type == "ibm_is_volume")) | .index')
                        test="${VOL_LIST[$x]/$str/}"
                        vol=$(echo "$test" | cut -d"-" -f3-)
                        VOL_DESTINATION=${VOL_SOURCE//"$VOL_INDEX"/"${subnet_name}-${j}-${vol}"}
                        if [ -n "$VOL_SOURCE" ] || [ -n "$VOL_DESTINATION" ]; then
                            echo "terraform state mv \"$VOL_SOURCE\" \"$VOL_DESTINATION\""
                            terraform state mv "$VOL_SOURCE" "$VOL_DESTINATION"
                        fi
                    fi
                done
            fi
        done
    done
}

# run
function main() {
    verify_required_env_var
    ibmcloud_login
    get_details
    update_state
}

main
