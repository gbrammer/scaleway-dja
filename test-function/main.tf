terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
  }
  required_version = ">= 0.13"
}

provider "scaleway" {
}

variable "DB_HOST" {
    type = string
    sensitive = true
    default = ""
}

variable "DB_USER" {
    type = string
    sensitive = true
    default = ""
}

variable "DB_PASS" {
    type = string
    sensitive = true
    default = ""
}

variable "DB_NAME" {
    type = string
    sensitive = true
    default = ""
}

variable "AWS_ACCESS_KEY_ID" {
    type = string
    sensitive = true
    default = ""
}

variable "AWS_SECRET_ACCESS_KEY" {
    type = string
    sensitive = true
    default = ""
}

variable "SCW_AWS_ACCESS_KEY_ID" {
    type = string
    sensitive = true
    default = ""
}

variable "SCW_AWS_SECRET_ACCESS_KEY" {
    type = string
    sensitive = true
    default = ""
}

variable "COCKPIT_LOG_URL" {
    type = string
    sensitive = true
    default = ""
}

variable "COCKPIT_API_KEY" {
    type = string
    sensitive = true
    default = ""
}

variable "COCKPIT_LOG_TOKEN" {
    type = string
    sensitive = true
    default = ""
}

resource "time_rotating" "rotate_after_a_year" {
  rotation_years = 1
}

# Project to be referenced in the IAM policy
data "scaleway_account_project" "default" {
  name = "Initialization"
}

# IAM resources
resource "scaleway_iam_application" "func_auth" {
  name = "function-auth"
}

resource "scaleway_iam_policy" "access_private_funcs" {
  application_id = scaleway_iam_application.func_auth.id
  rule {
    project_ids = [data.scaleway_account_project.default.id]
    permission_set_names = ["FunctionsPrivateAccess"]
  }
}
resource "scaleway_iam_api_key" "api_key" {
  application_id = scaleway_iam_application.func_auth.id
  expires_at     = time_rotating.rotate_after_a_year.rotation_rfc3339
}

# Function resources
resource "scaleway_function_namespace" "private" {
  name        = "fnsp"
}

resource "scaleway_function" "private" {
  namespace_id = scaleway_function_namespace.private.id
  name         = "msaexp-func"
  runtime      = "python312"
  handler      = "handlers/handle.handle"
  privacy      = "private"
  zip_file     = "handlers.zip"
  zip_hash     = filesha256("handlers.zip")
  deploy       = true
  timeout      = 180
  memory_limit = 2048
  # cpu_limit    = 1120
  secret_environment_variables = {
      "DB_HOST" = "${var.DB_HOST}"
      "DB_USER" = "${var.DB_USER}"
      "DB_PASS" = "${var.DB_PASS}"
      "DB_NAME" = "${var.DB_NAME}"
      "AWS_ACCESS_KEY_ID" = "${var.AWS_ACCESS_KEY_ID}"
      "AWS_SECRET_ACCESS_KEY" = "${var.AWS_SECRET_ACCESS_KEY}"
      "SCA_AWS_ACCESS_KEY_ID" = "${var.SCW_AWS_ACCESS_KEY_ID}"
      "SCA_AWS_SECRET_ACCESS_KEY" = "${var.SCW_AWS_SECRET_ACCESS_KEY}"
      "COCKPIT_LOG_URL" = "${var.COCKPIT_LOG_URL}"
      "COCKPIT_API_KEY" = "${var.COCKPIT_API_KEY}"
      "COCKPIT_LOG_TOKEN" = "${var.COCKPIT_LOG_TOKEN}"
  }
}

# Output the secret key and the function's endpoint for the curl command
output "secret_key" {
  value = scaleway_iam_api_key.api_key.secret_key
  sensitive = true
}
output "function_endpoint" {
  value = scaleway_function.private.domain_name
}