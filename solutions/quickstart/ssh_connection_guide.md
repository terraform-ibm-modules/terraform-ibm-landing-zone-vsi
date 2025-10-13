# SSH Connection Guide for IBM Cloud VSI

This guide will help you connect to your IBM Cloud Virtual Server Instance (VSI) using SSH.

## Prerequisites

- Your VSI has been successfully deployed.
- You have the SSH private key file.
- Your VSI is assigned a floating IP address. A floating IP is a system-provisioned public IP address that is accessible from the internet.
- `jq` command-line JSON processor is installed.
- `ibmcloud` CLI tool installed.

#### Step 1:  Get your Workspace ID from Projects UI

#### Step 2: Set environment variables

```bash
# Set your workspace ID (replace with your workspace ID)
WORKSPACE_ID="YOUR_WORKSPACE_ID_HERE"  # example: "us-south.workspace.projects-service.8f617fb9"
  ```

#### Step 3: Run the following command to extract the VSI name, floating IP address and private IP address

```bash
ibmcloud schematics output --id $WORKSPACE_ID -o JSON | jq -r '.[0].output_values[] | select(.fip_list) | .fip_list.value[0] | "VSI Name: \(.name)\nFloating IP: \(.floating_ip)\nPrivate IP: \(.ipv4_address)"'
```

**Expected Output:**
```bash
VSI Name: qs1-qs-vsi-e3f5-001
Floating IP: 150.240.160.54
Private IP: 10.10.10.4
```

#### Step 4: Run the following command to extract the SSH private key and saves it as a file `vsi-private-key.pem` with secure `400` permissions and display the private key file path. If you are using an existing SSH key, you can skip this step and go to step 5

```bash
ibmcloud schematics output --id $WORKSPACE_ID -o JSON > /tmp/ws_output.json && KEY_FILE="vsi-private-key.pem" && jq -r '.[0].output_values[] | select(.ssh_private_key) | .ssh_private_key.value' /tmp/ws_output.json > "$KEY_FILE" && chmod 400 "$KEY_FILE" && echo "Private Key saved to: $(pwd)/$KEY_FILE" && rm /tmp/ws_output.json
```

**Expected Output:**
```bash
Private Key saved to: /Users/mac/vsi-private-key.pem
```

#### Step 5: Determine Your Username

The default username depends on your operating system:

| Operating System | Default Username |
|-----------------|------------------|
| Ubuntu | `ubuntu` |
| Redhat | `vpcuser` |
| Debian | `vpcuser` |
| Fedora | `core` |
| CentOS | `vpcuser` |

#### Step 6: Connect via SSH

Use the following command template to connect to your VSI:

```bash
ssh -i vsi-private-key.pem <username>@<floating_ip>
```

#### Example Connection Commands

For different operating systems, replace the placeholders with your actual values:

#### Ubuntu:
```bash
ssh -i vsi-private-key.pem ubuntu@150.240.69.61
```

#### Redhat, Debian, and CentOS:
```bash
ssh -i vsi-private-key.pem vpcuser@150.240.69.61
```

#### Fedora:
```bash
ssh -i vsi-private-key.pem core@150.240.69.61
```

#### Step 7: First Connection

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
