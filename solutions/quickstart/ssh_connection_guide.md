# SSH Connection Guide for IBM Cloud VSI

This guide will help you connect to your IBM Cloud Virtual Server Instance (VSI) using SSH.

## Prerequisites

- Your VSI has been successfully deployed
- You have the SSH private key file
- Your VSI is assigned a floating IP address. A floating IP is a system-provisioned public IP address that is accessible from the internet.

## Get Your SSH Private Key and Floating UP

Get Workspace ID from Projects:

![Projects](https://raw.githubusercontent.com/terraform-ibm-modules/terraform-ibm-landing-zone-vsi/main/reference-architectures/project.png)

Set environment variables

```bash
# Set your workspace ID (replace with your actual workspace ID)
WORKSPACE_ID="YOUR_WORKSPACE_ID_HERE"  # example: "us-south.workspace.projects-service.8f617fb9"

# Set your Schematics URL (replace with your region's URL)
SCHEMATICS_URL="YOUR_REGION_SCHEMATICS_URL_HERE"  # example: "https://us-south.schematics.cloud.ibm.com"

# Set your IBMCLOUD_API_KEY
IBMCLOUD_API_KEY="your-api-key-here" # pragma: allowlist secret

# Set access token
ACCESS_TOKEN=$(curl -X POST \
  --location 'https://iam.cloud.ibm.com/identity/token' \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=urn:ibm:params:oauth:grant-type:apikey' \ # pragma: allowlist secret
  --data-urlencode "apikey=$IBMCLOUD_API_KEY" | jq -r '.access_token')
  ```

Run this command to save your SSH private key, extract Floating IP address, and set file permission:

```bash

# Fetch outputs and extract SSH key and floating IP
curl -X GET "${SCHEMATICS_URL}/v1/workspaces/${WORKSPACE_ID}/output_values?hide=false" \
    -L -s \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" | \
    jq -r '.[0].output_values[] | select(.ssh_private_key) | .ssh_private_key.value' > private_key.pem && \
    chmod 400 private_key.pem && \
    echo && \
    echo "Floating IP $(curl -X GET "${SCHEMATICS_URL}/v1/workspaces/${WORKSPACE_ID}/output_values?hide=false" \
    -L -s \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" | \
    jq -r '.[0].output_values[] | select(.fip_list) | .fip_list.value[0].floating_ip')" && \
    echo && \
    echo "Private key to connect to SSH: $(pwd)/private_key.pem" && \
    echo
```

This command will:
- Extracts the SSH private key and saves it as `private_key.pem` with secure `400` permissions
- Displays the floating IP address and private key file path

## Step 3: Determine Your Username

The default username depends on your operating system:

| Operating System | Default Username |
|-----------------|------------------|
| Ubuntu | `ubuntu` |
| Red Hat Enterprise Linux (RHEL) | `vpcuser` |
| Debian | `vpcuser` |
| Fedora CoreOS | `core` |
| CentOS Stream | `vpcuser` |


## Step 4: Connect via SSH

Use the following command template to connect to your VSI:

```bash
ssh -i private_key.pem <username>@<floating_ip>
```

### Example Connection Commands

For different operating systems, replace the placeholders with your actual values:

#### Ubuntu:
```bash
ssh -i private_key.pem ubuntu@150.240.69.61
```

#### RHEL, Debian, and CentOS:
```bash
ssh -i private_key.pem vpcuser@150.240.69.61
```

#### Fedora:
```bash
ssh -i private_key.pem core@150.240.69.61
```

## Step 5: First Connection

On your first connection, you'll see a message about host authenticity:

```
The authenticity of host '150.240.69.61 (150.240.69.61)' can't be established.
ECDSA key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no)?
```

Type `yes` and press Enter to continue.

Now you should be successfully connected to your IBM Cloud VSI with the welcome message:

```
==========================================
Welcome to Your IBM Cloud VSI!
==========================================
Server Information:
- Hostname: sky-da-qs-vsi-69f8-001
- IP Address: 10.10.10.4
- OS: Debian GNU/Linux 13 (trixie)

```
