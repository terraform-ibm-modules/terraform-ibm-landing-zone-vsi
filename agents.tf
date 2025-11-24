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
    startswith(local.os_image, "debian-11") ? "logs-router-agent-deb11-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "debian-12") || startswith(local.os_image, "ubuntu-22") ? "logs-router-agent-deb12-${var.logging_agent_version}.deb" :
    startswith(local.os_image, "red-8") ? "logs-router-agent-rhel8-${var.logging_agent_version}.rpm" :
    startswith(local.os_image, "red-9") ? "logs-router-agent-${var.logging_agent_version}.rpm" :
    ""
  )
  # determine install tool to use (rpm or dpkg)
  logging_agent_install_command = (var.install_logging_agent ?
    startswith(local.os_image, "ubuntu") || startswith(local.os_image, "debian") ? "dpkg -i" :
    startswith(local.os_image, "red") ? "rpm -ivh" :
    "" : ""
  )
  logging_agent_download_url = var.install_logging_agent ? "https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/${local.package_name}" : ""
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

  # list of commands that will be run to download, install and configure the logging agent
  logging_agent_user_data_runcmd = [
    "mkdir -p ${local.logging_agent_download_dir} 2>&1 | tee -a ${local.logging_agent_install_log}",
    "curl --retry 5 -fL -o ${local.logging_agent_download_dir}/${local.package_name} ${local.logging_agent_download_url} 2>&1 | tee -a ${local.logging_agent_install_log}",
    "${local.logging_agent_install_command} ${local.logging_agent_download_dir}/${local.package_name} 2>&1 | tee -a ${local.logging_agent_install_log}",
    "${local.logging_agent_config_command} 2>&1 | tee -a ${local.logging_agent_install_log}",
    "echo \"Complete. See /var/log/messages for agent logs.'\" 2>&1 | tee -a ${local.logging_agent_install_log}",
  ]

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
    ""
  )
  monitoring_agent_command = <<-EOT
    ${local.monitoring_agent_download_dir}/${local.monitoring_agent_installer_script} \
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
    "${local.monitoring_kernel_header_install_cmd} 2>&1 | tee -a ${local.monitoring_agent_install_log}",
    "mkdir -p ${local.monitoring_agent_download_dir} 2>&1 | tee -a ${local.monitoring_agent_install_log}",
    "curl --retry 5 -fL -o ${local.monitoring_agent_download_dir}/${local.monitoring_agent_installer_script} https://ibm.biz/install-sysdig-agent 2>&1 | tee -a ${local.monitoring_agent_install_log}",
    "chmod +x ${local.monitoring_agent_download_dir}/${local.monitoring_agent_installer_script} 2>&1 | tee -a ${local.monitoring_agent_install_log}",
    "${local.monitoring_agent_command} 2>&1 | tee -a ${local.monitoring_agent_install_log}",
    "echo \"Complete. See /opt/draios/logs/draios.log for agent logs.'\" 2>&1 | tee -a ${local.monitoring_agent_install_log}",
  ]
}

##############################################################################
# Final user data
##############################################################################

locals {
  # extract runcmd block from var.user_data if one exists, otherwise empty list
  provided_user_data_runcmd = try(yamldecode(var.user_data)["runcmd"], [])

  # conditionally merge all 3 of the run cmd lists (user, logging, monitoring) based on boolean switches
  merged_runcmd = concat(flatten([local.provided_user_data_runcmd, [var.install_logging_agent ? local.logging_agent_user_data_runcmd : []], [var.install_monitoring_agent ? local.monitoring_user_data_runcmd : []]]))

  # re-encode the user data into yaml format after adding in the combined runcmd commands
  # note the comment to the top to let cloud-init know this is a cloud config file
  user_data_yaml = var.user_data != null || var.install_logging_agent || var.install_monitoring_agent ? join("\n", ["#cloud-config"], [yamlencode(merge(try(yamldecode(var.user_data), {}), { "runcmd" = local.merged_runcmd }))]) : null
}
