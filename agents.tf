# Lookup the image name from the ID
data "ibm_is_image" "image_name" {
  count      = var.image_id != null ? 1 : 0
  identifier = var.image_id
}

##############################################################################
# Logging agent
##############################################################################

locals {
  os_image = var.image_id != null ? data.ibm_is_image.image_name[0].os : ""
  # returns empty string if OS not supported
  package_name = (
    startswith(local.os_image, "ubuntu-20") ? "logs-router-agent-ubuntu20-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "ubuntu-22") ? "logs-router-agent-ubuntu22-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "ubuntu-24") ? "logs-router-agent-ubuntu24-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "debian-11") ? "logs-router-agent-deb11-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "debian-12") ? "logs-router-agent-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "red-8") ? "logs-router-agent-rhel8-${var.logging_agent_version}.rpm" :
    startswith(local.os_image, "red-9") ? "logs-router-agent-${var.logging_agent_version}.rpm" :
    startswith(local.os_image, "windows") ? "logs-agent-windows-${var.logging_agent_version}.zip" :
    ""
  )
  is_windows = startswith(local.os_image, "windows")
  # determine install tool to use (rpm or dpkg)
  logging_agent_install_command = (var.install_logging_agent ?
    startswith(local.os_image, "ubuntu") || startswith(local.os_image, "debian") ? "dpkg -i" :
    startswith(local.os_image, "red") ? "rpm -ivh" :
    "" : ""
  )
  logging_agent_download_url = var.install_logging_agent && local.package_name != "" ? "https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/${local.package_name}" : ""
  logging_agent_download_dir = "/run/logging-agent"
  logging_agent_install_log  = "${local.logging_agent_download_dir}/logs-agent-install.log"
  logging_agent_auth_value   = var.logging_auth_mode == "IAMAPIKey" ? "-k ${var.logging_api_key != null ? var.logging_api_key : ""}" : "-d ${var.logging_trusted_profile_id != null ? var.logging_trusted_profile_id : ""}"
  # construct the post config command - see https://cloud.ibm.com/docs/cloud-logs?topic=cloud-logs-agent-linux
  logging_agent_config_command = <<-EOT
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

  # list of commands that will be run to download, install and configure the logging agent for Linux
  logging_agent_user_data_runcmd = [
    "bash -lc 'set -o pipefail; mkdir -p ${local.logging_agent_download_dir} 2>&1 | tee -a ${local.logging_agent_install_log}'",
    "bash -lc 'set -o pipefail; curl --retry 5 -fL -o ${local.logging_agent_download_dir}/${local.package_name} ${local.logging_agent_download_url} 2>&1 | tee -a ${local.logging_agent_install_log}'",
    "bash -lc 'test -f ${local.logging_agent_download_dir}/${local.package_name}'",
    "bash -lc 'set -o pipefail; ${local.logging_agent_install_command} ${local.logging_agent_download_dir}/${local.package_name} 2>&1 | tee -a ${local.logging_agent_install_log}'",
    "bash -lc 'set -o pipefail; ${local.logging_agent_config_command} 2>&1 | tee -a ${local.logging_agent_install_log}'",
    "bash -lc 'set -o pipefail; echo \"Complete. See /var/log/messages for agent logs.\" 2>&1 | tee -a ${local.logging_agent_install_log}'",
  ]

  logging_windows_download_dir = "C:\\Temp\\logging-agent"
  logging_windows_zip_path     = "${local.logging_windows_download_dir}\\${local.package_name}"
  logging_windows_install_dir  = "C:\\Program Files\\logs-agent"
  logging_windows_config_url   = "https://logs-router-agent-config.s3.us.cloud-object-storage.appdomain.cloud/configure-logs-agent.ps1"
  logging_windows_config_path  = "${local.logging_windows_install_dir}\\configure-logs-agent.ps1"
  logging_windows_install_log  = "${local.logging_windows_download_dir}\\logs-agent-install.log"

  # list of commands that will be run to download, install and configure the logging agent for Windows
  logging_windows_script = <<-EOT
    $logging_agent_download_url = "${local.logging_agent_download_url}"
    $downloadDir = "${local.logging_windows_download_dir}"
    $zipPath = "${local.logging_windows_zip_path}"
    $installDir = "${local.logging_windows_install_dir}"
    $configUrl = "${local.logging_windows_config_url}"
    $configPath = "${local.logging_windows_config_path}"
    $logPath = "${local.logging_windows_install_log}"

    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

    $maxRetries = 5
    $retryCount = 0
    $downloaded = $false

    while (-not $downloaded -and $retryCount -lt $maxRetries) {
        try {
            Invoke-WebRequest `
                -Uri $logging_agent_download_url `
                -OutFile $zipPath `
                -UseBasicParsing
            $downloaded = $true
        } catch {
            $retryCount++
            Start-Sleep -Seconds 5
        }
    }

    if (-not $downloaded) {
        throw "Failed to download logging agent after $maxRetries attempts."
    }

    Expand-Archive -Path $zipPath -DestinationPath "C:\Program Files" -Force

    Invoke-WebRequest -Uri $configUrl -OutFile $configPath -UseBasicParsing

    if (-not (Test-Path $configPath)) {
        throw "configure-logs-agent.ps1 not found at $configPath"
    }

    if ("${var.logging_auth_mode}" -eq "IAMAPIKey") {
        & $configPath `
            -TargetHost "${var.logging_target_host != null ? var.logging_target_host : ""}" `
            -TargetPort ${var.logging_target_port} `
            -AuthMode IAMAPIKey `
            -IAMEnv ${var.logging_use_private_endpoint ? "PrivateProduction" : "Production"} `
            -IAMApiKey "${var.logging_api_key != null ? var.logging_api_key : ""}" `
            ${var.logging_secure_access_enabled ? "-VSISecureAccess" : ""}
    } elseif ("${var.logging_auth_mode}" -eq "VSITrustedProfile") {
        & $configPath `
            -TargetHost "${var.logging_target_host != null ? var.logging_target_host : ""}" `
            -TargetPort ${var.logging_target_port} `
            -AuthMode VSITrustedProfile `
            -IAMEnv ${var.logging_use_private_endpoint ? "PrivateProduction" : "Production"} `
            -TrustedProfile "${var.logging_trusted_profile_id != null ? var.logging_trusted_profile_id : ""}" `
            ${var.logging_secure_access_enabled ? "-VSISecureAccess" : ""}
    } else {
        throw "Unsupported logging_auth_mode: ${var.logging_auth_mode}"
    }

    if (-not (Test-Path "C:\Program Files\logs-agent\bin\fluent-bit.exe")) {
        throw "fluent-bit.exe not found."
    }

    if (-not (Test-Path "C:\Program Files\logs-agent\etc\fluent-bit.conf")) {
        throw "fluent-bit.conf not found."
    }

    sc.exe create fluent-bit binpath= "C:\Program Files\logs-agent\bin\fluent-bit.exe -c \"C:\Program Files\logs-agent\etc\fluent-bit.conf\""
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create fluent-bit service. sc.exe exit code: $LASTEXITCODE"
    }

    if ("${var.logging_auth_mode}" -eq "IAMAPIKey") {
        New-ItemProperty `
            -Path "HKLM:\System\CurrentControlSet\Services\fluent-bit" `
            -Name "Environment" `
            -Value @("IAM_API_KEY=${var.logging_api_key != null ? var.logging_api_key : ""}") `
            -PropertyType MultiString `
            -Force | Out-Null
    }

    sc.exe start fluent-bit
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start fluent-bit service. sc.exe exit code: $LASTEXITCODE"
    }
  EOT

}

##############################################################################
# Monitoring agent
##############################################################################

locals {
  monitoring_agent_download_dir     = "/run/monitoring-agent"
  monitoring_agent_installer_script = "monitoring-agent.sh"
  monitoring_agent_install_log      = "${local.monitoring_agent_download_dir}/monitoring-agent-install.log"
  monitoring_api_endpoint           = var.monitoring_collector_endpoint != null ? join(".", slice(split(".", var.monitoring_collector_endpoint), 1, length(split(".", var.monitoring_collector_endpoint)))) : ""
  # determine command to use to install the kernel header files
  monitoring_kernel_header_install_cmd = (
    startswith(local.os_image, "centos") || startswith(local.os_image, "fedora") || startswith(local.os_image, "red") ? "sudo yum -y install kernel-devel-$(uname -r)" :
    startswith(local.os_image, "debian") || startswith(local.os_image, "ubuntu") ? "sudo apt-get -y install linux-headers-$(uname -r)" :
    startswith(local.os_image, "windows") ? "echo 'Windows handles agent installation internally'" :
    ""
  )
  monitoring_agent_command = <<-EOT
    bash ${local.monitoring_agent_download_dir}/${local.monitoring_agent_installer_script} \
      --access_key ${var.monitoring_access_key != null ? var.monitoring_access_key : ""} \
      --collector ${var.monitoring_collector_endpoint != null ? var.monitoring_collector_endpoint : ""} \
      --collector_port ${var.monitoring_collector_port} \
      --secure true \
      --check_certificate false \
      ${length(var.monitoring_tags) > 0 ? "--tags" : ""} ${length(var.monitoring_tags) > 0 ? join(",", var.monitoring_tags) : ""} \
      --additional_conf 'sysdig_api_endpoint: ${local.monitoring_api_endpoint}\nhost_scanner:\n  enabled: true\n  scan_on_start: true\nkspm_analyzer:\n  enabled: true' \
      ${var.monitoring_agent_version != null ? "--version ${var.monitoring_agent_version}" : ""}
  EOT

  monitoring_user_data_runcmd = [
    "bash -lc 'set -o pipefail; ${local.monitoring_kernel_header_install_cmd} 2>&1 | tee -a ${local.monitoring_agent_install_log}'",
    "bash -lc 'set -o pipefail; mkdir -p ${local.monitoring_agent_download_dir} 2>&1 | tee -a ${local.monitoring_agent_install_log}'",
    "bash -lc 'set -o pipefail; curl --retry 5 -fL -o ${local.monitoring_agent_download_dir}/${local.monitoring_agent_installer_script} https://ibm.biz/install-sysdig-agent 2>&1 | tee -a ${local.monitoring_agent_install_log}'",
    "bash -lc 'test -f ${local.monitoring_agent_download_dir}/${local.monitoring_agent_installer_script}'",
    "bash -lc 'set -o pipefail; chmod +x ${local.monitoring_agent_download_dir}/${local.monitoring_agent_installer_script} 2>&1 | tee -a ${local.monitoring_agent_install_log}'",
    "bash -lc 'set -o pipefail; ${local.monitoring_agent_command} 2>&1 | tee -a ${local.monitoring_agent_install_log}'",
    "bash -lc 'set -o pipefail; echo \"Complete. See /opt/draios/logs/draios.log for agent logs.\" 2>&1 | tee -a ${local.monitoring_agent_install_log}'",
  ]
  monitoring_windows_bundle_url      = "https://github.com/sysdiglabs/Sysdig-Windows-Prometheus-Bundle/releases/download/v${var.monitoring_windows_bundle_version}/windows_exporter-${var.monitoring_windows_bundle_version}-x64.msi"
  monitoring_windows_download_dir    = "C:\\Temp\\monitoring-agent"
  monitoring_windows_msi_path        = "${local.monitoring_windows_download_dir}\\windows_exporter-${var.monitoring_windows_bundle_version}-x64.msi"
  monitoring_windows_install_dir     = "C:\\Program Files\\windows_exporter"
  monitoring_windows_install_log     = "${local.monitoring_windows_download_dir}\\monitoring-agent-install.log"
  monitoring_windows_collectors      = "cpu,logical_disk,os,system,net"
  monitoring_collector_full_endpoint = var.monitoring_collector_endpoint != null ? "https://${var.monitoring_collector_endpoint}/prometheus/remote/write" : ""

  monitoring_windows_script = <<-EOT
    $monitoring_windows_bundle_url = "${local.monitoring_windows_bundle_url}"
    $monitoring_collector_endpoint = "${local.monitoring_collector_full_endpoint}"
    $monitoring_access_key         = "${var.monitoring_access_key != null ? var.monitoring_access_key : ""}"
    $downloadDir = "${local.monitoring_windows_download_dir}"
    $msiPath     = "${local.monitoring_windows_msi_path}"
    $installDir  = "${local.monitoring_windows_install_dir}"

    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

    $maxRetries = 5; $retryCount = 0; $downloaded = $false
    while (-not $downloaded -and $retryCount -lt $maxRetries) {
        try {
            Invoke-WebRequest -Uri $monitoring_windows_bundle_url -OutFile $msiPath -UseBasicParsing
            $downloaded = $true
        } catch {
            $retryCount++; Start-Sleep -Seconds 5
        }
    }
    if (-not $downloaded) { throw "Failed to download monitoring agent after $maxRetries attempts." }

    # Pre-create config.yml so the MSI's Remove-Item step doesn't fail
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    New-Item -ItemType File -Force -Path "$installDir\\config.yml" | Out-Null

    $collectors = "${local.monitoring_windows_collectors}"
    $logPath = "${local.monitoring_windows_install_log}"

    $arguments = @(
        "/i", "`"$msiPath`"",
        "ENABLED_COLLECTORS=$collectors",
        "SYSDIG_URL=$monitoring_collector_endpoint",
        "SYSDIG_TOKEN=$monitoring_access_key",
        "/qn", "/norestart", "/l*v", "`"$logPath`""
    )

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) { Write-Error "Installation failed with exit code $($process.ExitCode). Check $logPath" }

    Start-Sleep -Seconds 5
    Get-Service -Name *prometheus*, *exporter* | Select-Object Name, Status
  EOT
}

##############################################################################
# Final user data
##############################################################################

locals {
  # extract runcmd block from var.user_data if one exists, otherwise empty list
  provided_user_data_runcmd = try(yamldecode(var.user_data)["runcmd"], [])

  # conditionally merge all 3 of the run cmd lists (user, logging, monitoring) based on boolean switches
  merged_runcmd = concat(flatten([local.provided_user_data_runcmd, [var.install_logging_agent ? local.logging_agent_user_data_runcmd : []], [var.install_monitoring_agent ? local.monitoring_user_data_runcmd : []]]))

  windows_combined_script = trimspace(join("\n\n", compact([
    var.user_data != null ? trimspace(var.user_data) : "",
    var.install_logging_agent ? trimspace(local.logging_windows_script) : "",
    var.install_monitoring_agent ? trimspace(local.monitoring_windows_script) : "",
  ])))
  windows_runcmd    = <<-EOT
  Content-Type: text/x-shellscript; charset="us-ascii"
  MIME-Version: 1.0
  Content-Transfer-Encoding: 7bit
  Content-Disposition: attachment; filename="install-agents.ps1"

  #ps1_sysnative
  ${local.windows_combined_script}
  EOT
  windows_mime_part = local.is_windows && local.windows_combined_script != "" ? local.windows_runcmd : null

  windows_user_data = local.windows_mime_part
  # re-encode the user data into yaml format after adding in the combined runcmd commands
  # note the comment to the top to let cloud-init know this is a cloud config file
  user_data_yaml = local.is_windows ? (
    local.windows_user_data
    ) : (
    var.user_data != null ||
    var.install_logging_agent ||
    var.install_monitoring_agent
    ) ? join("\n", [
      "#cloud-config",
      yamlencode(
        merge(
          try(yamldecode(var.user_data), {}),
          { runcmd = local.merged_runcmd }
        )
      ),
  ]) : null
}
