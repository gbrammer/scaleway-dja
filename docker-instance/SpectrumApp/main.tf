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

# Source image

variable "registry_image_name" {
    type = string
    sensitive = false
    default = "dja-msaexp-spectra"
}

variable "registry_image_namespace" {
    type = string
    sensitive = false
    default = "ns-dja-app-containers"
}

variable "registry_image_version" {
    type = string
    sensitive = false
    default = "latest"
}

######### Environment
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
#####################

resource "time_rotating" "rotate_after_a_year" {
  rotation_years = 1
}

#### Container info
data "scaleway_account_project" "default" {
  name = "Initialization"
}

data "scaleway_registry_namespace" "main" {
  name = "${var.registry_image_namespace}"
}

data "scaleway_registry_image" "main" {
  namespace_id = data.scaleway_registry_namespace.main.id
  name         = "${var.registry_image_name}"
}

data "scaleway_registry_image_tag" "version" {
  image_id = data.scaleway_registry_image.main.id
  name     = "${var.registry_image_version}"
}

resource "scaleway_iam_application" "container_auth" {
  name = "container-auth"
}

resource "scaleway_iam_policy" "access_private_containers" {
  application_id = scaleway_iam_application.container_auth.id
  rule {
    project_ids          = [data.scaleway_account_project.default.id]
    permission_set_names = ["ContainersPrivateAccess"]
  }
}

resource "scaleway_iam_api_key" "api_key" {
  application_id = scaleway_iam_application.container_auth.id
  expires_at     = time_rotating.rotate_after_a_year.rotation_rfc3339
}

resource "scaleway_container_namespace" "main" {
  name        = "ns-spec-container"
  description = "Spectra container namespace"
}

resource "scaleway_container" "private" {
  name            = "test-spec-container"
  description     = "test container"
  # tags            = ["tag1", "tag2"]
  namespace_id    = scaleway_container_namespace.main.id
  registry_image  = "${data.scaleway_registry_namespace.main.endpoint}/${var.registry_image_name}:${var.registry_image_version}"
  registry_sha256 = data.scaleway_registry_image_tag.version.digest
  port            = 8080
  cpu_limit       = 2048
  memory_limit    = 4096
  min_scale       = 3
  max_scale       = 5
  timeout         = 600
  # max_concurrency = 80
  scaling_option {
      concurrent_requests_threshold = 4
  }
  privacy         = "private"
  protocol        = "http1"
  deploy          = true

  command = ["python3", "./app.py"]
  # args    = ["some", "args"]

  /*environment_variables = {
    "foo" = "var"
  }*/
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

output "container_digest" {
    value = data.scaleway_registry_image_tag.version.digest
    sensitive = false
}

output "secret_key" {
  value     = scaleway_iam_api_key.api_key.secret_key
  sensitive = true
}

output "container_endpoint" {
  value = scaleway_container.private.domain_name
}
