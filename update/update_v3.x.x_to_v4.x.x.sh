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
"

STATE_LOCATION=""
VOL_RESOURCES=""
REVERT=false

helpFunction() {
    echo ""
    echo "Usage: $0 -v VPC_ID -r REGION -t STATE_LOCATION [-z]"
    echo -e "\t-v , seperated IDs or names of the VPC in which the VSIs are deployed which needs to be tracked by the newer version of the terraform module."
    echo -e "\t-r Region of the VPC."
    echo -e "\t-t Path of the terrafom state file. If no path is specified, the current state will be shown."
    echo -e "\t-z [Optional] Flag to revert the changes done to the state file."
    exit 1 # Exit script after printing help
}

while getopts "v:r:t:z" opt; do
    case "$opt" in
    v) VPC_ID="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    t) STATE_LOCATION="$OPTARG" ;;
    z) REVERT=true ;;
    ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

# Print helpFunction in case parameters are empty
if [ "$REVERT" == false ]; then
    if [ -z "$VPC_ID" ] || [ -z "$REGION" ]; then
        echo "VPC_ID or REGION is empty"
        helpFunction
    fi
fi

function dependency_check() {
    dependencies=("ibmcloud" "jq")
    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            echo "\"$dependency\" is not installed. Please install $dependency."
            exit 1
        fi
    done
    plugin_dependencies=("vpc-infrastructure")
    for plugin_dependency in "${plugin_dependencies[@]}"; do
        if ! ibmcloud plugin show "$plugin_dependency" >/dev/null; then
            echo "\"$plugin_dependency\" ibmcloud plugin is not installed. Please install $plugin_dependency."
            exit 1
        fi
    done
    echo "All dependencies are available!"
}

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
    printf "\nVerification complete\n"
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
    printf "\nLogin complete\n"
}

function get_details() {
    terraform init -upgrade
    if [ -z "$STATE_LOCATION" ]; then
        STATE=$(terraform show -json)
    else
        STATE=$(terraform show -json "$STATE_LOCATION")
    fi
}

function update_state() {
    VPC_LIST=()
    IFS=',' read -r -d '' -a VPC_LIST <<<"$VPC_ID"
    for vpc in "${!VPC_LIST[@]}"; do
        VPC_DATA=$(ibmcloud is vpc "${VPC_LIST[$vpc]//$'\n'/}" --output JSON --show-attached -q)
        SUBNET_LIST=()
        while IFS='' read -r line; do SUBNET_LIST+=("$line"); done < <(echo "$VPC_DATA" | jq -r '.subnets[] | .id')

        for i in "${!SUBNET_LIST[@]}"; do
            subnet_name=$(echo "$VPC_DATA" | jq -r --arg subnet_id "${SUBNET_LIST[$i]}" '.subnets[] | select(.id == $subnet_id) | .name')
            vsi_names=$(echo "$STATE" | jq -r --arg subnet "${SUBNET_LIST[$i]}" '.. | objects | select((.values.primary_network_interface[0].subnet == $subnet) and (.type == "ibm_is_instance")) | .index')

            VSI_LIST=()
            IFS=$'\n' read -r -d '' -a VSI_LIST <<<"$vsi_names"

            for j in "${!VSI_LIST[@]}"; do
                SOURCE=$(echo "$STATE" | jq -r --arg vsi "${VSI_LIST[$j]}" '.. | objects | select((.index == $vsi) and (.type == "ibm_is_instance")) | .address')
                DESTINATION=${SOURCE//"${VSI_LIST[$j]}"/"${subnet_name}-${j}"}

                if [ -n "$SOURCE" ] || [ -n "$DESTINATION" ]; then
                    MOVED_PARAMS+=("'$SOURCE' '$DESTINATION'")
                    REVERT_PARAMS+=("'$DESTINATION' '$SOURCE'")
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
                    VOL_LIST=()
                    IFS=$'\n' read -r -d '' -a VOL_LIST <<<"$VOL_RESOURCES"
                    for x in "${!VOL_LIST[@]}"; do
                        VOL_SOURCE=$(echo "$STATE" | jq -r --arg index "${VOL_LIST[$x]}" '.. | objects | select((.values.name == $index) and (.type == "ibm_is_volume")) | .address')

                        if [ -n "$VOL_SOURCE" ]; then
                            VOL_INDEX=$(echo "$STATE" | jq -r --arg index "${VOL_LIST[$x]}" '.. | objects | select((.values.name == $index) and (.type == "ibm_is_volume")) | .index')
                            test="${VOL_LIST[$x]/$str/}"
                            vol=$(echo "$test" | cut -d"-" -f3-)
                            VOL_DESTINATION=${VOL_SOURCE//"$VOL_INDEX"/"${subnet_name}-${j}-${vol}"}
                            if [ -n "$VOL_SOURCE" ] || [ -n "$VOL_DESTINATION" ]; then
                                MOVED_PARAMS+=("'$VOL_SOURCE' '$VOL_DESTINATION'")
                                REVERT_PARAMS+=("'$VOL_DESTINATION' '$VOL_SOURCE'")
                            fi
                        fi
                    done
                fi
            done
        done
    done
}
function update_local_state() {
    while read -r line; do
        eval "$line"
    done <"./moved.txt"
}

function revert_local_state() {
    if ! [ -f "./revert.txt" ]; then
        echo "Revert.txt does not exist."
    else
        if [ -s "./revert.txt" ]; then
            while read -r line; do
                eval "$line"
            done <"./revert.txt"
        else
            echo "Revert.txt is empty."
        fi
    fi

}
create_txt() {
    for movedparam in "${!MOVED_PARAMS[@]}"; do
        echo "terraform state mv ${MOVED_PARAMS[$movedparam]}" >>./moved.txt
    done
    for revertparam in "${!REVERT_PARAMS[@]}"; do
        echo "terraform state mv ${REVERT_PARAMS[$revertparam]}" >>./revert.txt
    done
}

create_txt_files() {
    # Define the file path and content
    MOVED_JSON="./moved.txt"
    REVERT_JSON="./revert.txt"

    # Check if the file exists
    if [ -f "$MOVED_JSON" ] || [ -f "$REVERT_JSON" ]; then
        # If the file exists, empty it
        echo "" >"$MOVED_JSON"
        echo "" >"$REVERT_JSON"
    else
        # If the file does not exist, create it
        touch "$MOVED_JSON"
        touch "$REVERT_JSON"
    fi

}

# run
function main() {
    if [ "$REVERT" == false ]; then
        dependency_check
        create_txt_files
        verify_required_env_var
        ibmcloud_login
        get_details
        update_state
        create_txt
        update_local_state
    else

        revert_local_state
    fi
}

main
