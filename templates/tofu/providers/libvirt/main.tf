terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

# Configure the Libvirt Provider
provider "libvirt" {
  uri = "qemu:///system"
}

# Create a cloud-init disk
resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "torrust-cloudinit.iso"
  user_data = templatefile("${path.module}/cloud-init.yml", {
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDVvNSEw9lRv0wIHXHle7jNpGBgQfJ5fsT4WlntGqzVW0smjSAy9GgsERUrkX8N4jz5NherZVJpzMGn6V69CiClyptXeUUuz+BmWAtBH8pIJf5quku4Xmmxg9+hlal5JtdqH5ZwSCrF0EFzb2fS/hTk9npwZknR5Av4Nk+iREM+EvB/rbOfnXU7xNezIJ6sZNt2zIH3bROsmthmffEegosSQ2KO4YGHv6mW0SV/O+X22RHelP/3tAMu/2mM1ecdMOib32IlG38PjHnlhB6gmUoQ1USsPILxhaZLdU7pKs7Jx3FRZHuPQHNqj8ZVMzYZ2ONZ+uYUzg+kocJGiqV20PiJBrzTvUzoknvzU7l8cI5smmrXdZ3EKtykdbLLe21T8hrL4KndYYKTeXRTM63kHjluvX/ZVr4jmnz3GHTwf1HFnTmrq7jSaF5n4Y82qEu1ps9KFSCx4fXHxUeSNIzIqF+AOOS0t1nVWgc+q22p9khgnKsakVrTK+WEbvGSqjEWkzh2J2MjCwuc0IJClBrpqNFyOW/+eZutbrDjX7NAxBYCJZd64tCC2/BAefvbCDWIR2t2XGY8JcaPH5MvRnXR391kq/savEe8527AIkp3ZaV99js1psUIv67434bggpPz1LwpQW2bBA9mxW1XFXZsDQEdefXUujmcb4EbuYcow+SAEw== testing-key-for-torrust-deploy"
  })
}

# Download Ubuntu 22.04 LTS image
resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-22.04-base.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# Create a volume for our VM
resource "libvirt_volume" "torrust_vm_disk" {
  name           = "torrust-tracker-vm.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = 10737418240  # 10GB
  format         = "qcow2"
}

# Create the VM
resource "libvirt_domain" "torrust_vm" {
  name   = "torrust-tracker"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.torrust_vm_disk.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Output the VM IP
output "vm_ip" {
  value = libvirt_domain.torrust_vm.network_interface[0].addresses[0]
}

output "vm_name" {
  value = libvirt_domain.torrust_vm.name
}
