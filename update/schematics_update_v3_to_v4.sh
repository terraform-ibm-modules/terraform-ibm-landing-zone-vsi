#!/usr/bin/env bash

PRG=$(basename -- "${0}")
USAGE="
usage: ./${PRG}

    Required environment variables:
    - IBMCLOUD_API_KEY
    - WORKSPACE_ID

    Dependencies:
    - IBM Cloud CLI
    - IBM Cloud CLI 'is' plugin
    - IBM Cloud CLI 'schematics' plugin
    - jq
"
VOL_RESOURCES=""
VOL_NAMES=""
REVERT=false
VPC_IBMCLOUD_API_KEY=""

helpFunction() {
    echo ""
    echo "Usage: $0 -v VPC_ID -r VPC_REGION [-k VPC_IBMCLOUD_API_KEY] [-z]"
    echo -e "\t-v , seperated IDs or names of the VPC in which the VSIs are deployed which needs to be tracked by the newer version of the terraform module."
    echo -e "\t-r Region of the VPC."
    echo -e "\t-k [Optional] IBMCLOUD_API_KEY to access the VPCs, if the VPCs are deployed in a different account."
    echo -e "\t-z [Optional] Flag to revert the changes done to the state file."
    exit 1 # Exit script after printing help
}

while getopts "v:r:k:z" opt; do
    case "$opt" in
    v) VPC_ID="$OPTARG" ;;
    r) VPC_REGION="$OPTARG" ;;
    k) VPC_IBMCLOUD_API_KEY="$OPTARG" ;;
    z) REVERT=true ;;
    ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

# Print helpFunction in case parameters are empty
if [ "$REVERT" == false ]; then
    if [ -z "$VPC_ID" ] || [ -z "$VPC_REGION" ]; then
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
    plugin_dependencies=("schematics" "vpc-infrastructure")
    for plugin_dependency in "${plugin_dependencies[@]}"; do
        if ! ibmcloud plugin show "$plugin_dependency" >/dev/null; then
            echo "\"$plugin_dependency\" ibmcloud plugin is not installed. Please install $plugin_dependency."
            exit 1
        fi
    done
    echo "All dependencies are available!"
}

# Check that env contains required vars
function verify_required_env_var() {
    printf "\n#### VERIFYING ENV ####\n\n"
    all_env_vars_exist=true
    env_var_array=(IBMCLOUD_API_KEY WORKSPACE_ID)
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

# Log in to IBM Cloud using IBMCLOUD_API_KEY env var value
function ibmcloud_login() {
    printf "\n#### IBM CLOUD LOGIN ####\n\n"
    WORKSPACE_REGION=$(echo "$WORKSPACE_ID" | cut -d "." -f 1)
    attempts=1
    until ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$WORKSPACE_REGION" || [ $attempts -ge 3 ]; do
        attempts=$((attempts + 1))
        echo "Error logging in to IBM Cloud CLI..."
        sleep 3
    done
    printf "\nLogin complete\n"
}

function get_workspace_details() {
    template_id="$(ibmcloud schematics workspace get --id "$WORKSPACE_ID" -o json | jq -r .template_data[0].id)"
    OUTPUT="$(ibmcloud schematics state pull --id "$WORKSPACE_ID" --template "$template_id")"
    STATE=${OUTPUT//'OK'/}
}

function update_state() {
    if [[ -z "$VPC_IBMCLOUD_API_KEY" ]]; then
        until ibmcloud target -r "$VPC_REGION" || [ "$attempts" -ge 3 ]; do
            attempts=$((attempts + 1))
            echo "Error logging in to IBM Cloud CLI..."
            sleep 3
        done
    else
        until ibmcloud login --apikey "$VPC_IBMCLOUD_API_KEY" -r "$VPC_REGION" || [ $attempts -ge 3 ]; do
            attempts=$((attempts + 1))
            echo "Error logging in to IBM Cloud CLI..."
            sleep 3
        done
    fi
    VPC_LIST=()
    VPC_ID=${VPC_ID//","/" "}
    IFS=' ' read -r -a VPC_LIST <<<"$VPC_ID"
    for vpc in "${!VPC_LIST[@]}"; do
        VPC_DATA=$(ibmcloud is vpc "${VPC_LIST[$vpc]//$'\n'/}" --output JSON --show-attached -q)
        SUBNET_LIST=()
        while IFS='' read -r line; do SUBNET_LIST+=("$line"); done < <(echo "$VPC_DATA" | jq -r '.subnets[] | .id')
        ADDRESS_LIST=()
        while IFS='' read -r line; do ADDRESS_LIST+=("$line"); done < <(echo "$STATE" | jq -r '.resources[] | select(.type == "ibm_is_instance") | .module')

        for i in "${!SUBNET_LIST[@]}"; do
            for j in "${!ADDRESS_LIST[@]}"; do
                VSI_RESOURCES="$(echo "$STATE" | jq -r --arg address "${ADDRESS_LIST[$j]}" '.resources[] | select((.type == "ibm_is_instance") and (.module == $address)) | .instances')"
                subnet_name=$(echo "$VPC_DATA" | jq -r --arg subnet_id "${SUBNET_LIST[$i]}" '.subnets[] | select(.id == $subnet_id) | .name')
                vsi_names=$(echo "$VSI_RESOURCES" | jq -r --arg subnet_id "${SUBNET_LIST[$i]}" '.[] | select(.attributes.primary_network_interface[0].subnet == $subnet_id) | .index_key')
                VSI_LIST=()
                IFS=$'\n' read -r -d '' -a VSI_LIST <<<"$vsi_names"

                for x in "${!VSI_LIST[@]}"; do
                    SOURCE="${ADDRESS_LIST[$j]}.ibm_is_instance.vsi[\"${VSI_LIST[$x]}\"]"
                    DESTINATION="${ADDRESS_LIST[$j]}.ibm_is_instance.vsi[\"${subnet_name}-${x}\"]"

                    if [ -n "${VSI_LIST[$x]}" ] && [ -n "${subnet_name}" ]; then
                        MOVED_PARAMS+=("$SOURCE, $DESTINATION")
                        REVERT_PARAMS+=("$DESTINATION, $SOURCE")
                    fi
                    if [ -n "${VSI_LIST[$x]}" ]; then
                        VOL_NAMES=$(echo "$VSI_RESOURCES" | jq -r --arg vsi "${VSI_LIST[$x]}" '.[] | select(.index_key == $vsi) | .attributes.volume_attachments[].volume_name')

                    fi
                    if [ -n "${VSI_LIST[$x]}" ]; then
                        FIP_RESOURCES="$(echo "$STATE" | jq -r --arg address "${ADDRESS_LIST[$j]}" '.resources[] | select((.type == "ibm_is_floating_ip") and (.module == $address)) | .instances')"
                    fi
                    if [ -n "$FIP_RESOURCES" ]; then
                        FIP_SOURCE="${ADDRESS_LIST[$j]}.ibm_is_floating_ip.vsi_fip[\"${VSI_LIST[$x]}\"]"
                        FIP_DESTINATION="${ADDRESS_LIST[$j]}.ibm_is_floating_ip.vsi_fip[\"${subnet_name}-${x}\"]"
                        if [ -n "${VSI_LIST[$x]}" ] && [ -n "${subnet_name}" ]; then
                            MOVED_PARAMS+=("$FIP_SOURCE, $FIP_DESTINATION")
                            REVERT_PARAMS+=("$FIP_DESTINATION, $FIP_SOURCE")
                        fi
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
                        VOL_ADDRESS_LIST=()
                        while IFS='' read -r line; do VOL_ADDRESS_LIST+=("$line"); done < <(echo "$STATE" | jq -r '.resources[] | select(.type == "ibm_is_volume") | .module')
                        VOL_NAME=()
                        IFS=$'\n' read -r -d '' -a VOL_NAME <<<"$VOL_NAMES"
                        for a in "${!VOL_NAME[@]}"; do
                            for b in "${!VOL_ADDRESS_LIST[@]}"; do
                                VOL_RESOURCES="$(echo "$STATE" | jq -r --arg address "${VOL_ADDRESS_LIST[$b]}" '.resources[] | select((.type == "ibm_is_volume") and (.module == $address)) | .instances')"
                                vol_names=$(echo "$VOL_RESOURCES" | jq -r --arg vol1 "${VOL_NAME[$a]}" '.[] | select(.attributes.name == $vol1) | .index_key')
                                VOL_LIST=()
                                IFS=$'\n' read -r -d '' -a VOL_LIST <<<"$vol_names"
                                for c in "${!VOL_LIST[@]}"; do
                                    if [ -n "${VOL_LIST[$c]}" ]; then
                                        VOL_SOURCE="${ADDRESS_LIST[$j]}.ibm_is_volume.volume[\"${VOL_LIST[$c]}\"]"
                                        test="${VOL_LIST[$c]/$str/}"
                                        vol=$(echo "$test" | cut -d"-" -f3-)
                                        VOL_DESTINATION="${ADDRESS_LIST[$j]}.ibm_is_volume.volume[\"${subnet_name}-${x}-${vol}\"]"
                                        if [ -n "${VOL_LIST[$c]}" ] || [ -n "${subnet_name}" ]; then
                                            MOVED_PARAMS+=("$VOL_SOURCE, $VOL_DESTINATION")
                                            REVERT_PARAMS+=("$VOL_DESTINATION, $VOL_SOURCE")
                                        fi
                                    fi
                                done
                            done
                        done
                    fi
                done
            done
        done
    done

}

function update_schematics() {
    if [[ -z "$VPC_IBMCLOUD_API_KEY" ]]; then
        until ibmcloud target -r "$WORKSPACE_REGION" || [ "$attempts" -ge 3 ]; do
            attempts=$((attempts + 1))
            echo "Error logging in to IBM Cloud CLI..."
            sleep 3
        done
    else
        until ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$WORKSPACE_REGION" || [ $attempts -ge 3 ]; do
            attempts=$((attempts + 1))
            echo "Error logging in to IBM Cloud CLI..."
            sleep 3
        done
    fi

    ibmcloud schematics workspace commands --id "$WORKSPACE_ID" --file ./moved.json
}

function revert_schematics() {
    if ! [ -f "./revert.json" ]; then
        echo "Revert.json does not exist."
    else
        if [ -s "./revert.json" ]; then
            if [[ -z "$VPC_IBMCLOUD_API_KEY" ]]; then
                until ibmcloud target -r "$WORKSPACE_REGION" || [ "$attempts" -ge 3 ]; do
                    attempts=$((attempts + 1))
                    echo "Error logging in to IBM Cloud CLI..."
                    sleep 3
                done
            else
                until ibmcloud login --apikey "$IBMCLOUD_API_KEY" -r "$WORKSPACE_REGION" || [ $attempts -ge 3 ]; do
                    attempts=$((attempts + 1))
                    echo "Error logging in to IBM Cloud CLI..."
                    sleep 3
                done
            fi
            ibmcloud schematics workspace commands --id "$WORKSPACE_ID" --file ./revert.json
        else
            echo "Revert.json is empty."
        fi
    fi

}
create_json() {
    for movedparam in "${!MOVED_PARAMS[@]}"; do
        jq --arg command_params "${MOVED_PARAMS[$movedparam]}" --arg command_name "Move$movedparam" '.commands += [{"command": "state mv","command_params": $command_params, "command_name": $command_name, "command_onerror": "abort"}]' moved.json >temp.json && mv temp.json moved.json
    done
    for revertparam in "${!REVERT_PARAMS[@]}"; do
        jq --arg command_params "${REVERT_PARAMS[$revertparam]}" --arg command_name "Revert$revertparam" '.commands += [{"command": "state mv","command_params": $command_params, "command_name": $command_name, "command_onerror": "continue"}]' revert.json >temp.json && mv temp.json revert.json
    done
    jq '.commands += [{"command": "state list","command_params": "", "command_name": "Test", "command_onerror": "continue"}]' revert.json >temp.json && mv temp.json revert.json
}

create_json_files() {
    # Define the file path and content
    MOVED_JSON="./moved.json"
    REVERT_JSON="./revert.json"

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

    # Add new content to the file
    echo '{
    "commands": [],
    "operation_name": "workspace Command",
    "description": "Executing command"
    }
    ' >>$MOVED_JSON

    echo '{
    "commands": [],
    "operation_name": "workspace Command",
    "description": "Executing command"
    }
    ' >>$REVERT_JSON
}

# run
function main() {
    if [ "$REVERT" == false ]; then
        dependency_check
        create_json_files
        verify_required_env_var
        ibmcloud_login
        get_workspace_details
        update_state
        create_json
        update_schematics
    else
        verify_required_env_var
        ibmcloud_login
        revert_schematics
    fi
}

main
