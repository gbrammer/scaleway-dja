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
  name        = "private-function-namespace"
}

resource "scaleway_function" "private" {
  namespace_id = scaleway_function_namespace.private.id
  runtime      = "python312"
  handler      = "handlers/handle.handle"
  privacy      = "private"
  zip_file     = "functions.zip"
  zip_hash     = filesha256("functions.zip")
  deploy       = true
}

# Output the secret key and the function's endpoint for the curl command
output "secret_key" {
  value = scaleway_iam_api_key.api_key.secret_key
  sensitive = true
}
output "function_endpoint" {
  value = scaleway_function.private.domain_name
}