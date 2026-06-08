# Lookup the image name from the ID
data "ibm_is_image" "image_name" {
  count      = var.image_id != null ? 1 : 0
  identifier = var.image_id
}

##############################################################################
# Logging agent
##############################################################################

locals {
  os_image   = var.image_id != null ? data.ibm_is_image.image_name[0].os : ""
  is_windows = startswith(local.os_image, "windows")

  # returns empty string if OS not supported
  package_name = (
    startswith(local.os_image, "ubuntu-20") ? "logs-router-agent-ubuntu20-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "debian-11") ? "logs-router-agent-deb11-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "debian-12") || startswith(local.os_image, "ubuntu-22") || startswith(local.os_image, "ubuntu-24") ? "logs-router-agent-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "red-8") ? "logs-router-agent-rhel8-${var.logging_agent_version}.rpm" :
    startswith(local.os_image, "red-9") ? "logs-router-agent-${var.logging_agent_version}.rpm" :
    startswith(local.os_image, "windows") ? "logs-router-agent-${var.logging_agent_version}.msi" :
    ""
  )

  # determine install tool to use (rpm, dpkg, or msiexec for Windows)
  logging_agent_install_command = (var.install_logging_agent ?
    startswith(local.os_image, "ubuntu") || startswith(local.os_image, "debian") ? "dpkg -i" :
    startswith(local.os_image, "red") ? "rpm -ivh" :
    startswith(local.os_image, "windows") ? "msiexec /i" :
    "" : ""
  )

  logging_agent_download_url = var.install_logging_agent ? "https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/${local.package_name}" : ""

  # Linux paths
  logging_agent_download_dir_linux = "/run/logging-agent"
  logging_agent_install_log_linux  = "${local.logging_agent_download_dir_linux}/logs-agent-install.log"

  # Windows paths
  logging_agent_download_dir_windows = "C:\\Temp\\logging-agent"
  logging_agent_install_log_windows  = "${local.logging_agent_download_dir_windows}\\logs-agent-install.log"

  # Select appropriate paths based on OS
  logging_agent_download_dir = local.is_windows ? local.logging_agent_download_dir_windows : local.logging_agent_download_dir_linux
  logging_agent_install_log  = local.is_windows ? local.logging_agent_install_log_windows : local.logging_agent_install_log_linux

  logging_agent_auth_value = var.logging_auth_mode == "IAMAPIKey" ? "-k ${var.logging_api_key != null ? var.logging_api_key : ""}" : "-d ${var.logging_trusted_profile_id != null ? var.logging_trusted_profile_id : ""}"

  # Linux post config command - see https://cloud.ibm.com/docs/cloud-logs?topic=cloud-logs-agent-linux
  logging_agent_config_command_linux = <<-EOT
    /opt/fluent-bit/bin/post-config.sh \
      -h ${var.logging_target_host != null ? var.logging_target_host : ""} \
      -p ${var.logging_target_port} \
      -t ${var.logging_target_path} \
      -a ${var.logging_auth_mode} \
      ${local.logging_agent_auth_value} \
      -i ${var.logging_use_private_endpoint ? "PrivateProduction" : "Production"} \
      -s ${var.logging_secure_access_enabled} \
      ${var.logging_application_name != null ? "--application-name \"${var.logging_application_name}\"" : ""} \
      ${var.logging_subsystem_name != null ? "--subsystem-name \"${var.logging_subsystem_name}\"" : ""}
  EOT

  # Windows post config command - see https://cloud.ibm.com/docs/cloud-logs?topic=cloud-logs-agent-windows
  logging_agent_config_command_windows = <<-EOT
    & 'C:\Program Files\logs-router-agent\post-config.ps1' `
      -h ${var.logging_target_host != null ? var.logging_target_host : ""} `
      -p ${var.logging_target_port} `
      -t ${var.logging_target_path} `
      -a ${var.logging_auth_mode} `
      ${local.logging_agent_auth_value} `
      -i ${var.logging_use_private_endpoint ? "PrivateProduction" : "Production"} `
      -s ${var.logging_secure_access_enabled} `
      ${var.logging_application_name != null ? "--application-name \"${var.logging_application_name}\"" : ""} `
      ${var.logging_subsystem_name != null ? "--subsystem-name \"${var.logging_subsystem_name}\"" : ""}
  EOT

  # Linux commands for logging agent installation
  logging_agent_user_data_runcmd_linux = [
    "mkdir -p ${local.logging_agent_download_dir_linux} 2>&1 | tee -a ${local.logging_agent_install_log_linux}",
    "curl --retry 5 -fL -o ${local.logging_agent_download_dir_linux}/${local.package_name} ${local.logging_agent_download_url} 2>&1 | tee -a ${local.logging_agent_install_log_linux}",
    "${local.logging_agent_install_command} ${local.logging_agent_download_dir_linux}/${local.package_name} 2>&1 | tee -a ${local.logging_agent_install_log_linux}",
    "${local.logging_agent_config_command_linux} 2>&1 | tee -a ${local.logging_agent_install_log_linux}",
    "echo \"Complete. See /var/log/messages for agent logs.'\" 2>&1 | tee -a ${local.logging_agent_install_log_linux}",
  ]

  # Windows PowerShell commands for logging agent installation
  logging_agent_user_data_powershell_windows = <<-EOT
    # Create download directory
    New-Item -ItemType Directory -Force -Path "${local.logging_agent_download_dir_windows}" | Out-File -Append "${local.logging_agent_install_log_windows}"

    # Download logging agent
    $ProgressPreference = 'SilentlyContinue'
    $maxRetries = 5
    $retryCount = 0
    $downloaded = $false

    while (-not $downloaded -and $retryCount -lt $maxRetries) {
        try {
            Invoke-WebRequest -Uri "${local.logging_agent_download_url}" -OutFile "${local.logging_agent_download_dir_windows}\${local.package_name}" -UseBasicParsing
            $downloaded = $true
            "Successfully downloaded logging agent" | Out-File -Append "${local.logging_agent_install_log_windows}"
        } catch {
            $retryCount++
            "Download attempt $retryCount failed: $_" | Out-File -Append "${local.logging_agent_install_log_windows}"
            Start-Sleep -Seconds 5
        }
    }

    if (-not $downloaded) {
        "Failed to download logging agent after $maxRetries attempts" | Out-File -Append "${local.logging_agent_install_log_windows}"
        exit 1
    }

    # Install logging agent
    Start-Process msiexec.exe -ArgumentList "/i `"${local.logging_agent_download_dir_windows}\${local.package_name}`" /qn /norestart /l*v `"${local.logging_agent_install_log_windows}`"" -Wait -NoNewWindow

    # Configure logging agent
    ${local.logging_agent_config_command_windows} *>> "${local.logging_agent_install_log_windows}"

    "Complete. See C:\ProgramData\logs-router-agent\logs for agent logs." | Out-File -Append "${local.logging_agent_install_log_windows}"
  EOT

  # Select appropriate commands based on OS
  logging_agent_user_data_runcmd = local.is_windows ? [] : local.logging_agent_user_data_runcmd_linux
}

##############################################################################
# Monitoring agent
##############################################################################

locals {
  # Linux paths
  monitoring_agent_download_dir_linux     = "/run/monitoring-agent"
  monitoring_agent_installer_script_linux = "monitoring-agent.sh"
  monitoring_agent_install_log_linux      = "${local.monitoring_agent_download_dir_linux}/monitoring-agent-install.log"

  # Windows paths
  monitoring_agent_download_dir_windows     = "C:\\Temp\\monitoring-agent"
  monitoring_agent_installer_script_windows = "monitoring-agent.ps1"
  monitoring_agent_install_log_windows      = "${local.monitoring_agent_download_dir_windows}\\monitoring-agent-install.log"

  # Select appropriate paths based on OS
  monitoring_agent_download_dir     = local.is_windows ? local.monitoring_agent_download_dir_windows : local.monitoring_agent_download_dir_linux
  monitoring_agent_installer_script = local.is_windows ? local.monitoring_agent_installer_script_windows : local.monitoring_agent_installer_script_linux
  monitoring_agent_install_log      = local.is_windows ? local.monitoring_agent_install_log_windows : local.monitoring_agent_install_log_linux

  monitoring_api_endpoint = var.monitoring_collector_endpoint != null ? join(".", slice(split(".", var.monitoring_collector_endpoint), 1, length(split(".", var.monitoring_collector_endpoint)))) : ""

  # determine command to use to install the kernel header files (Linux only)
  monitoring_kernel_header_install_cmd = (
    startswith(local.os_image, "centos") || startswith(local.os_image, "fedora") || startswith(local.os_image, "red") ? "sudo yum -y install kernel-devel-$(uname -r)" :
    startswith(local.os_image, "debian") || startswith(local.os_image, "ubuntu") ? "sudo apt-get -y install linux-headers-$(uname -r)" :
    ""
  )

  # Linux monitoring agent command
  monitoring_agent_command_linux = <<-EOT
    ${local.monitoring_agent_download_dir_linux}/${local.monitoring_agent_installer_script_linux} \
      --access_key ${var.monitoring_access_key != null ? var.monitoring_access_key : ""} \
      --collector ${var.monitoring_collector_endpoint != null ? var.monitoring_collector_endpoint : ""} \
      --collector_port ${var.monitoring_collector_port} \
      --secure true \
      --check_certificate false \
      ${length(var.monitoring_tags) > 0 ? "--tags" : ""} ${length(var.monitoring_tags) > 0 ? join(",", var.monitoring_tags) : ""} \
      --additional_conf 'sysdig_api_endpoint: ${local.monitoring_api_endpoint}\nhost_scanner:\n  enabled: true\n  scan_on_start: true\nkspm_analyzer:\n  enabled: true' \
      ${var.monitoring_agent_version != null ? "--version ${var.monitoring_agent_version}" : ""}
  EOT

  # Linux monitoring agent installation commands
  monitoring_user_data_runcmd_linux = [
    "${local.monitoring_kernel_header_install_cmd} 2>&1 | tee -a ${local.monitoring_agent_install_log_linux}",
    "mkdir -p ${local.monitoring_agent_download_dir_linux} 2>&1 | tee -a ${local.monitoring_agent_install_log_linux}",
    "curl --retry 5 -fL -o ${local.monitoring_agent_download_dir_linux}/${local.monitoring_agent_installer_script_linux} https://ibm.biz/install-sysdig-agent 2>&1 | tee -a ${local.monitoring_agent_install_log_linux}",
    "chmod +x ${local.monitoring_agent_download_dir_linux}/${local.monitoring_agent_installer_script_linux} 2>&1 | tee -a ${local.monitoring_agent_install_log_linux}",
    "${local.monitoring_agent_command_linux} 2>&1 | tee -a ${local.monitoring_agent_install_log_linux}",
    "echo \"Complete. See /opt/draios/logs/draios.log for agent logs.'\" 2>&1 | tee -a ${local.monitoring_agent_install_log_linux}",
  ]

  # Windows PowerShell commands for monitoring agent installation
  monitoring_user_data_powershell_windows = <<-EOT
    # Create download directory
    New-Item -ItemType Directory -Force -Path "${local.monitoring_agent_download_dir_windows}" | Out-File -Append "${local.monitoring_agent_install_log_windows}"

    # Download monitoring agent installer
    $ProgressPreference = 'SilentlyContinue'
    $maxRetries = 5
    $retryCount = 0
    $downloaded = $false

    while (-not $downloaded -and $retryCount -lt $maxRetries) {
        try {
            Invoke-WebRequest -Uri "https://download.sysdig.com/stable/sysdig-agent/windows/sysdig-agent-installer.ps1" -OutFile "${local.monitoring_agent_download_dir_windows}\${local.monitoring_agent_installer_script_windows}" -UseBasicParsing
            $downloaded = $true
            "Successfully downloaded monitoring agent installer" | Out-File -Append "${local.monitoring_agent_install_log_windows}"
        } catch {
            $retryCount++
            "Download attempt $retryCount failed: $_" | Out-File -Append "${local.monitoring_agent_install_log_windows}"
            Start-Sleep -Seconds 5
        }
    }

    if (-not $downloaded) {
        "Failed to download monitoring agent installer after $maxRetries attempts" | Out-File -Append "${local.monitoring_agent_install_log_windows}"
        exit 1
    }

    # Prepare installation parameters
    $installParams = @{
        access_key = "${var.monitoring_access_key != null ? var.monitoring_access_key : ""}"
        collector = "${var.monitoring_collector_endpoint != null ? var.monitoring_collector_endpoint : ""}"
        collector_port = ${var.monitoring_collector_port}
        secure = $true
        check_certificate = $false
    }

    ${length(var.monitoring_tags) > 0 ? "$installParams['tags'] = \"${join(",", var.monitoring_tags)}\"" : ""}
    ${var.monitoring_agent_version != null ? "$installParams['agent_version'] = \"${var.monitoring_agent_version}\"" : ""}

    # Additional configuration
    $additionalConf = @"
sysdig_api_endpoint: ${local.monitoring_api_endpoint}
host_scanner:
  enabled: true
  scan_on_start: true
kspm_analyzer:
  enabled: true
"@

    $installParams['additional_conf'] = $additionalConf

    # Install monitoring agent
    try {
        & "${local.monitoring_agent_download_dir_windows}\${local.monitoring_agent_installer_script_windows}" @installParams *>> "${local.monitoring_agent_install_log_windows}"
        "Monitoring agent installation completed" | Out-File -Append "${local.monitoring_agent_install_log_windows}"
    } catch {
        "Monitoring agent installation failed: $_" | Out-File -Append "${local.monitoring_agent_install_log_windows}"
        exit 1
    }

    "Complete. See C:\ProgramData\Sysdig\logs for agent logs." | Out-File -Append "${local.monitoring_agent_install_log_windows}"
  EOT

  # Select appropriate commands based on OS
  monitoring_user_data_runcmd = local.is_windows ? [] : local.monitoring_user_data_runcmd_linux
}

##############################################################################
# Final user data
##############################################################################

locals {
  # Linux user data handling (cloud-init format)
  # extract runcmd block from var.user_data if one exists, otherwise empty list
  provided_user_data_runcmd = try(yamldecode(var.user_data)["runcmd"], [])

  # conditionally merge all 3 of the run cmd lists (user, logging, monitoring) based on boolean switches
  merged_runcmd = concat(flatten([local.provided_user_data_runcmd, [var.install_logging_agent ? local.logging_agent_user_data_runcmd : []], [var.install_monitoring_agent ? local.monitoring_user_data_runcmd : []]]))

  # re-encode the user data into yaml format after adding in the combined runcmd commands
  # note the comment to the top to let cloud-init know this is a cloud config file
  user_data_yaml_linux = var.user_data != null || var.install_logging_agent || var.install_monitoring_agent ? join("\n", ["#cloud-config"], [yamlencode(merge(try(yamldecode(var.user_data), {}), { "runcmd" = local.merged_runcmd }))]) : null

  # Windows user data handling (PowerShell format)
  # Combine user-provided PowerShell with agent installation scripts
  provided_user_data_powershell = var.user_data != null ? var.user_data : ""

  # Build the complete PowerShell script for Windows
  windows_powershell_script = join("\n\n", compact([
    "# User-provided PowerShell script",
    local.provided_user_data_powershell != "" ? local.provided_user_data_powershell : null,
    var.install_logging_agent ? "# Logging Agent Installation\n${local.logging_agent_user_data_powershell_windows}" : null,
    var.install_monitoring_agent ? "# Monitoring Agent Installation\n${local.monitoring_user_data_powershell_windows}" : null,
  ]))

  # Wrap PowerShell script in the required format for Windows user data
  # Windows instances expect PowerShell scripts wrapped in <powershell> tags or as base64
  user_data_yaml_windows = var.user_data != null || var.install_logging_agent || var.install_monitoring_agent ? "<powershell>\n${local.windows_powershell_script}\n</powershell>" : null

  # Select the appropriate user data format based on OS
  user_data_yaml = local.is_windows ? local.user_data_yaml_windows : local.user_data_yaml_linux
}
