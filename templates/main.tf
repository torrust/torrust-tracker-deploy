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
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC51CtUaREqCIyrLmSARLO+rmsIdJILfJVd/hPmGAHbE3+UvLaAhkU41M0slV12BezdLYELGcBYHhjQhlr1NVNMM1yGuopSAX1Yurqz1kSqps+vWpmb208QX3B1in7WyMbqN2cs/jbZ9NZ4JlZ3vwNxFZzPD5WeSBvRgTteRmztOBazHjJHprSGbsdWITDzFIx/8AzqiSu7MlRuFrZAoogl0woD1kgJ8K85l/VnMz82PJ3fStmsibz86M7RIiEDi5o7/VLU1Gs9Iv8bHIUZq6/wOIaYjDipuUBCJYKVpV7sBCnE02c9hHyjiXNP9iTlXtVKvm21gkJlLh/vM5zkRZEglmTkse/+w/Efk7ETdjMNAAm3a5I0F53mkRm4c1UUWRu49zEr8gr69KGzKNGXwffGrq84oOvpkf+A/t9wf0Pm2uUPWThPen6UJTvN4ZEOyTofkuvD02ikWr58rONQK4xTKnrXXCl5tdWED4Q+Xj6hftn9rhXMzy5Q088/aMgaVis= josecelano@josecelano-desktop"
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
