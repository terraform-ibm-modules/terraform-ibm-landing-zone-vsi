data "ibm_is_image" "image_name" {
  identifier = var.image_id
}

locals {
  # build the package string for cloud logs agent
  logging_agent_string = "https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/"
  os_image_version     = data.ibm_is_image.image_name.os
  package_extension = [
    length(regexall("^debian-11.*$", local.os_image_version)) > 0 ? "logs-router-agent-deb11-1.6.1.deb" :
    length(regexall("^debian-12.*$", local.os_image_version)) > 0 ? "logs-router-agent-1.6.1.deb" :
    length(regexall("^ubuntu.*$", local.os_image_version)) > 0 ? "logs-router-agent-1.6.1.deb" :
    length(regexall("^red.*-8.*$", local.os_image_version)) > 0 ? "logs-router-agent-rhel8-1.6.1.rpm" :
  "logs-router-agent-1.6.1.rpm"][0]
  logging_package_url = join("", [local.logging_agent_string, local.package_extension])

  # extract runcmd block from var.user_data if one exists, otherwise empty list
  provided_user_data_runcmd = try(yamldecode(var.user_data)["runcmd"], [])

  # list of commands that will be run to install the logging agent and config script
  logging_user_data_runcmd = [
    "mkdir -p /run/logging-agent",
    "curl -X GET -o /run/logging-agent/${local.package_extension} ${local.logging_package_url}",
    "${length(regexall("^.*deb$", local.package_extension)) > 0 ? "dpkg -i" : "rpm -ivh"} /run/logging-agent/${local.package_extension}",
    "curl -X GET -o /run/logging-agent/logs-agent-config.sh https://logs-router-agent-config.s3.us.cloud-object-storage.appdomain.cloud/post-config.sh",
    "chmod +x /run/logging-agent/logs-agent-config.sh",
    "/run/logging-agent/logs-agent-config.sh -h ${var.logging_target_host != null ? var.logging_target_host : ""} -p ${var.logging_target_port} -t ${var.logging_target_path} -a ${var.logging_auth_mode} ${var.logging_auth_mode == "IAMAPIKey" ? "-k" : "-d"} ${var.logging_auth_mode == "IAMAPIKey" ? (var.logging_api_key != null ? var.logging_api_key : "") : (var.logging_trusted_profile_id != null ? var.logging_trusted_profile_id : "")} -i ${var.logging_use_private_endpoint ? "PrivateProduction" : "Production"} --send-directly-to-icl"
  ]

  # list of commands that will be run to install the monitoring agent
  monitoring_user_data_runcmd = [
    "mkdir -p /run/monitoring-agent",
    "curl -sL -o /run/monitoring-agent/monitoring-agent.sh https://ibm.biz/install-sysdig-agent",
    "chmod +x /run/monitoring-agent/monitoring-agent.sh",
    "/run/monitoring-agent/monitoring-agent.sh --access_key ${var.monitoring_access_key != null ? var.monitoring_access_key : ""} --collector ${var.monitoring_collector_endpoint != null ? var.monitoring_collector_endpoint : ""} --collector_port ${var.monitoring_collector_port} --secure true --check_certificate false ${length(var.monitoring_tags) > 0 ? "--tags" : ""} ${length(var.monitoring_tags) > 0 ? join(",", var.monitoring_tags) : ""}"
  ]

  # conditionally merge all 3 of the run cmd lists (user, logging, monitoring) based on boolean switches
  merged_runcmd = concat(flatten([local.provided_user_data_runcmd, [var.install_logging_agent ? local.logging_user_data_runcmd : []], [var.install_monitoring_agent ? local.monitoring_user_data_runcmd : []]]))

  # re-encode the user data into yaml format after adding in the combined runcmd commands
  # note the comment to the top to let cloud-init know this is a cloud config file
  user_data_yaml = var.user_data != null || var.install_logging_agent || var.install_monitoring_agent ? join("\n", ["#cloud-config"], [yamlencode(merge(try(yamldecode(var.user_data), {}), { "runcmd" = local.merged_runcmd }))]) : null
}
