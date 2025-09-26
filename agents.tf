data "ibm_is_image" "image_name" {
  identifier = var.image_id
}

locals {
  # build the package string for cloud logs agent
  logging_agent_string = "https://logs-router-agent-install-packages.s3.us.cloud-object-storage.appdomain.cloud/"
  os_image_version     = data.ibm_is_image.image_name.os
  package_extension = [
    length(regexall("^debian-11.*$", local.os_image_version)) > 0 ? "logs-router-agent-deb11-1.6.0.deb" :
    length(regexall("^debian-12.*$", local.os_image_version)) > 0 ? "logs-router-agent-1.6.0.deb" :
    length(regexall("^ubuntu.*$", local.os_image_version)) > 0 ? "logs-router-agent-1.6.0.deb" :
    length(regexall("^red.*-8.*$", local.os_image_version)) > 0 ? "logs-router-agent-rhel8-1.6.0.rpm" :
  "logs-router-agent-1.6.0.rpm"][0]
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

  api_endpoint = var.sysdig_collector_endpoint != null ? join(".", slice(split(".", var.sysdig_collector_endpoint), 1, length(split(".", var.sysdig_collector_endpoint)))) : null

  bash_command = <<-EOT
    bash /run/sysdig-agent/sysdig-agent.sh --access_key ${var.sysdig_access_key != null ? var.sysdig_access_key : ""} --collector ${var.sysdig_collector_endpoint != null ? var.sysdig_collector_endpoint : ""} --collector_port ${var.sysdig_collector_port} --secure true --check_certificate false ${length(var.sysdig_tags) > 0 ? "--tags" : ""} ${length(var.sysdig_tags) > 0 ? join(",", var.sysdig_tags) : ""} --additional_conf 'sysdig_api_endpoint: ${local.api_endpoint}\nhost_scanner:\n  enabled: true\n  scan_on_start: true\nkspm_analyzer:\n  enabled: true'
  EOT


  sysdig_user_data_runcmd = [
    "mkdir -p /run/sysdig-agent",
    "for i in $(seq 1 5); do curl -fL -o /run/sysdig-agent/sysdig-agent.sh https://ibm.biz/install-sysdig-agent && break; echo \"Attempt $i failed, retrying in 10 seconds...\"; sleep 10; done",
    "chmod +x /run/sysdig-agent/sysdig-agent.sh",
    local.bash_command
  ]



  # conditionally merge all 3 of the run cmd lists (user, logging, sysdig) based on boolean switches
  merged_runcmd = concat(flatten([local.provided_user_data_runcmd, [var.install_logging_agent ? local.logging_user_data_runcmd : []], [var.install_sysdig_agent ? local.sysdig_user_data_runcmd : []]]))

  # re-encode the user data into yaml format after adding in the combined runcmd commands
  # note the comment to the top to let cloud-init know this is a cloud config file
  user_data_yaml = var.user_data != null || var.install_logging_agent || var.install_sysdig_agent ? join("\n", ["#cloud-config"], [yamlencode(merge(try(yamldecode(var.user_data), {}), { "runcmd" = local.merged_runcmd }))]) : null
}
