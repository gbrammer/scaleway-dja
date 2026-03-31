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

# Multiple
locals {
    instance_names = toset([
        for i in range(1): format("docker%02d", i)
    ])
}

# IP
resource "scaleway_instance_ip" "public_ip" {
    for_each = local.instance_names
}

# Instance
resource "scaleway_instance_server" "docker_instance" {
  
  for_each = local.instance_names
  
  type  = "DEV1-M" # 3 vCPU 4GB RAM 0.019
  image = "docker"
  ip_id = scaleway_instance_ip.public_ip[each.key].id
  
  name = each.value

  root_volume {
    delete_on_termination = true
    sbs_iops   = 15000
    size_in_gb = 32
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
        for k, v in scaleway_instance_server.docker_instance : k => v.public_ips
    }
    
    sensitive = false
}
