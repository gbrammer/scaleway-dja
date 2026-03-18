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

# IP
resource "scaleway_instance_ip" "public_ip" {}

resource scaleway_block_volume volume {
  iops       = 5000
  size_in_gb = 16
}

# Instance
resource "scaleway_instance_server" "docker_instance" {
  type  = "DEV1-M" # 3 vCPU 4GB RAM 0.019
  image = "docker"
  ip_id = scaleway_instance_ip.public_ip.id
  
  root_volume {
    delete_on_termination = true
  }

  additional_volume_ids = [scaleway_block_volume.volume.id]

  user_data = {
    # foo        = "bar"
    myfoo = "bar"
    cloud-init = file("${path.module}/cloud-init.yml")
  }
}

# Print public IP
output public_ip {
    value = scaleway_instance_server.docker_instance.public_ips
    sensitive = false
}
