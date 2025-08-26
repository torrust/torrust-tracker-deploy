[![Testing](https://github.com/torrust/torrust-tracker-deploy/actions/workflows/testing.yml/badge.svg)](https://github.com/torrust/torrust-tracker-deploy/actions/workflows/testing.yml)

# Torrust Tracker Deployment Tool

A modern Perl console application for deploying Torrust Tracker to Hetzner Cloud using Packer,
Terraform, and Ansible.

## Installation

Install cpanminus:

```bash
curl -L https://cpanmin.us | perl - --sudo App::cpanminus
```

Install local::lib:

```bash
cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
```

Install Carmel dependency manager:

```bash
cpanm Carmel
```

Set up the environment (add carmel to PATH and set PERL5LIB):

```bash
eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
export PATH="$HOME/perl5/bin:$PATH"
```

**Note:** You need to run the `eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)` command in each new
terminal session, or add it to your shell profile (`.bashrc`, `.zshrc`, etc.).

Then install project dependencies:

```bash
carmel install
```

## Usage

Run the application:

```bash
carmel exec -- ./bin/torrust-deploy help
```

## Commands

### provision

Provision a Torrust Tracker virtual machine using OpenTofu with libvirt provider:

```bash
carmel exec -- ./bin/torrust-deploy provision
```

This command will:

1. Copy OpenTofu configuration templates from `templates/provision/` directory
2. Initialize OpenTofu if needed
3. Create a minimal Ubuntu 22.04 LTS VM with hardcoded configuration
4. Start the VM and make it ready for use

#### Requirements

Before using the provision command, ensure you have:

- **OpenTofu** installed ([Download from opentofu.org](https://opentofu.org/docs/intro/install/))
- **libvirt/KVM** installed and running:

  ```bash
  sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
  sudo systemctl enable libvirtd
  sudo systemctl start libvirtd
  sudo usermod -aG libvirt $USER
  ```

- **Default libvirt storage pool** configured:

  ```bash
  virsh pool-list --all
  # If 'default' pool doesn't exist, create it:
  sudo virsh pool-define-as default dir - - - - "/var/lib/libvirt/images"
  sudo virsh pool-build default
  sudo virsh pool-start default
  sudo virsh pool-autostart default
  ```

#### VM Configuration

The VM is created with:

- **OS:** Ubuntu 22.04 LTS (Cloud Image)
- **CPU:** 2 vCPUs
- **Memory:** 2GB RAM
- **Disk:** 10GB
- **Network:** NAT with DHCP (192.168.122.0/24)
- **User:** `torrust` (with sudo access)
- **SSH:** Enabled (requires SSH key configuration in cloud-init.yml)

After provisioning, you can find the VM IP with:

```bash
cd build/tofu && tofu output
```

## Testing

Run the test suite:

```bash
carmel exec -- prove -l t/
```
