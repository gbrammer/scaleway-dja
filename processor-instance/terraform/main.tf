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

variable "server_image" {
  type        = string
  description = "Server image name like 'ubuntu_jammy'"
  default     = "processor-build0"
}

variable "instance_type" {
  type        = string
  description = "Scaleway instance type"
  default     = "DEV1-L" # vCPU 4GB RAM 0.019
}

variable "name_prefix" {
  type        = string
  description = "Server name prefix"
  default     = "worker"
}

variable "volume_size" {
  type        = number
  description = "Size of root volume in gb"
  default     = 16
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

data "scaleway_instance_image" "server_image" {
  name = var.server_image
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

# Instance
resource "scaleway_instance_server" "this_instance" {
  
  for_each = local.instance_names
  
  type  = var.instance_type
  image = data.scaleway_instance_image.server_image.id

  ip_id = scaleway_instance_ip.public_ip[each.key].id

  security_group_id = scaleway_instance_security_group.www.id
  
  name = each.value

  root_volume {
    delete_on_termination = true
    volume_type = "sbs_volume"
    sbs_iops    = 15000
    size_in_gb  = var.volume_size
  }

  user_data = {
    # foo        = "bar"
    # myfoo = "bar"
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
