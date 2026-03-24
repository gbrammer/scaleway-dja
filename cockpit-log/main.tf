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

data "scaleway_account_project" "main" {
  name = "Initialization"
}

resource "scaleway_iam_application" "cockpit" {
  name        = "app-cockpit-logs"
  description = "App for cockpit logs"
}

resource "scaleway_iam_policy" "cockpit_policy" {
  name           = "Policy for cockpit access"
  description    = "gives app access to cockpit functionality"
  application_id = scaleway_iam_application.cockpit.id
  rule {
    project_ids          = [data.scaleway_account_project.main.id]
    permission_set_names = ["ObservabilityFullAccess"]
  }
}

resource "time_rotating" "rotate_after_a_year" {
  rotation_years = 1
}

resource "scaleway_iam_api_key" "cockpit" {
  application_id = scaleway_iam_application.cockpit.id
  description    = "IAM key for cockpit-logs"
  expires_at     = time_rotating.rotate_after_a_year.rotation_rfc3339
}

resource "scaleway_cockpit_source" "log" {
  name = "cockpit-source-log"
  retention_days = 1
  type = "logs"
}

/*resource "scaleway_cockpit_source" "metrics" {
  name = "cockpit-source-metrics"
  retention_days = 1
  type = "metrics"
}*/

resource "scaleway_cockpit_token" "main" {
  /*project_id = data.scaleway_account_project.main.project_id*/
  name = "auto-cockpit-token"
  scopes {
    write_logs = true
    # write_metrics = true
  }
}

output cockpit_log_token {
    value = scaleway_cockpit_token.main.secret_key
    sensitive = true
}

output cockpit_api_access {
    value = scaleway_iam_api_key.cockpit.access_key
    sensitive = false
}

output cockpit_api_key {
    value = scaleway_iam_api_key.cockpit.secret_key
    sensitive = true
}

output cockpit_log_url {
    value = scaleway_cockpit_source.log.url
    sensitive = false
}

/*output cockpit_metrics_url {
    value = scaleway_cockpit_source.metrics.url
    sensitive = false
}*/