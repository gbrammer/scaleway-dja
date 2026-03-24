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

# Input number of instances
variable "instance_count" {
  type        = number
  description = "Number of instances to launch"
  default     = 1
}

variable "name_prefix" {
  type        = string
  description = "Server name prefix"
  default     = "worker"
}

variable "instance_type" {
  type        = string
  description = "Scaleway instance type"
  default     = "BASIC2-A4C-16G" # vCPU 4GB RAM 0.019
}

variable "snapshot_name" {
  type        = string
  description = "Block snapshot name"
  default     = "snap-grizli-processor5-arm64"
}

variable "volume_size" {
  type        = number
  description = "Size of root volume in gb"
  default     = 16
}

# userdata variables
variable "max_process_locks" {
  type        = number
  description = "Maximum number of process locks"
  default     = 2
}

variable "app_process_types" {
  type        = string
  description = "Types of app processes to run"
  default     = "assoc"
}

locals {
    instance_names = toset([
        for i in range(var.instance_count): format("${var.name_prefix}%02d", i)
    ])
}

# IP
resource "scaleway_instance_ip" "public_ip" {
    for_each = local.instance_names
}

# Snapshot volume
data "scaleway_block_snapshot" "snapshot" {
  name = var.snapshot_name
}

resource "scaleway_block_volume" "from_snapshot" {
  for_each = local.instance_names
  
  name = "${each.value}-block-volume"
  
  snapshot_id = data.scaleway_block_snapshot.snapshot.id
  iops        = 15000
  size_in_gb  = var.volume_size
}

# Security group
resource "scaleway_instance_security_group" "www" {
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"

  inbound_rule {
    action = "accept"
    port   = "80"
  }

  inbound_rule {
    action = "accept"
    port   = "22"
  }

  inbound_rule {
    action = "accept"
    port   = "8888"
  }

  inbound_rule {
    action = "accept"
    port   = "8080"
  }

}

resource "scaleway_instance_placement_group" "availability_group" {
    name = "${var.name_prefix}-group"
}

# Instance
resource "scaleway_instance_server" "this_instance" {
  
  for_each = local.instance_names
  
  type  = var.instance_type

  ip_id = scaleway_instance_ip.public_ip[each.key].id

  security_group_id = scaleway_instance_security_group.www.id
  
  name = each.value

  placement_group_id = scaleway_instance_placement_group.availability_group.id

  root_volume {
    delete_on_termination = true
    volume_type = "sbs_volume"
    name = scaleway_block_volume.from_snapshot[each.key].name
    volume_id = scaleway_block_volume.from_snapshot[each.key].id
  }

  user_data = {
    # foo        = "bar"
    max_process_locks = "${var.max_process_locks}"
    app_process_types = "${var.app_process_types}"
    cloud-init = file("${path.module}/cloud-init.yml")
  }
}

# Print public IP
output public_ip {

    value = {
        for k, v in scaleway_instance_server.this_instance : k => v.public_ips
    }
    
    sensitive = false
}
