##############################################################################
# Trusted Profile for Logging Agent
##############################################################################

locals {
  # Determine if we need to create a trusted profile
  create_logging_trusted_profile = var.install_logging_agent && var.logging_auth_mode == "VSITrustedProfile" && var.logging_trusted_profile_id == null

  # Extract Cloud Logs instance ID from ingress endpoint
  cloud_logs_instance_id = var.logging_target_host != null ? element(split(".", var.logging_target_host), 0) : null
}

# Create Trusted Profile for VSI logging agent
resource "ibm_iam_trusted_profile" "logging_profile" {
  count       = local.create_logging_trusted_profile ? 1 : 0
  name        = "${local.prefix}vsi-logging-trusted-profile"
  description = "Trusted profile for VSI instances to send logs to IBM Cloud Logs"
}

# Create claim rule to allow VSI instances to assume the trusted profile
resource "ibm_iam_trusted_profile_claim_rule" "vsi_claim_rule" {
  count      = local.create_logging_trusted_profile ? 1 : 0
  profile_id = ibm_iam_trusted_profile.logging_profile[0].profile_id
  type       = "Profile-CR"
  name       = "${local.prefix}vsi-claim-rule"
  realm_name = "https://iam.cloud.ibm.com/identity/compute"
  cr_type    = "VSI"
  expiration = 3600

  # Condition to match VSI instances in the specified VPC
  conditions {
    claim    = "vpc_id"
    operator = "EQUALS"
    value    = local.existing_vpc_id
  }
}

# Grant the trusted profile access to send logs to IBM Cloud Logs
# Using "Sender" role as per IBM Cloud Logs best practice - allows sending logs but not querying/tailing
resource "ibm_iam_trusted_profile_policy" "logging_policy" {
  count      = local.create_logging_trusted_profile ? 1 : 0
  profile_id = ibm_iam_trusted_profile.logging_profile[0].profile_id
  roles      = ["Sender"]

  resource_attributes {
    name     = "serviceName"
    operator = "stringEquals"
    value    = "logs"
  }

  dynamic "resource_attributes" {
    for_each = local.cloud_logs_instance_id != null ? [1] : []
    content {
      name     = "serviceInstance"
      operator = "stringEquals"
      value    = local.cloud_logs_instance_id
    }
  }
}

##############################################################################
