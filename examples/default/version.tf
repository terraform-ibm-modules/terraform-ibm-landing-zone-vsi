terraform {
  required_version = ">= 1.0.0"
  experiments      = [module_variable_optional_attrs]
  required_providers {
    # Pin to the lowest provider version of the range defined in the main module's version.tf to ensure lowest version still works
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.45.0"
    }
    # The tls provider is not actually required by the module itself, just this example, so OK to use ">=" here instead of locking into a version
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.2"
    }
  }
}