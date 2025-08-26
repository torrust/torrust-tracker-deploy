[![Testing](https://github.com/torrust/torrust-tracker-deploy/actions/workflows/testing.yml/badge.svg)](https://github.com/torrust/torrust-tracker-deploy/actions/workflows/testing.yml)

# Torrust Tracker Deployment Tool

A modern Perl console application for deploying Torrust Tracker to cloud providers using
OpenTofu/Terraform and cloud-init for VM configuration.

## Architecture Decision: Cloud-Init vs Golden Images

This project uses cloud-init for VM configuration instead of building golden images with tools like
Packer. While golden images could speed up provisioning by pre-installing the torrust user, Docker,
and other basic setup, we chose cloud-init because:

- **Cross-cloud compatibility**: No way to generate a single base image that works across multiple  
  cloud providers
- **Deployment frequency**: Since deployment is typically done once, the extra time for cloud-init  
  configuration is acceptable
- **Simplicity**: Eliminates the complexity of managing and maintaining custom images across  
  different providers
- **Transparency**: All VM configuration is visible in the cloud-init templates

## Perl Version Requirement

This project requires **Perl v5.38** or higher. We chose v5.38 specifically because:

- **Modern Perl features**: Enables `strict` and `warnings` by default without explicit `use` statements
- **GitHub Actions compatibility**: v5.38 is the default Perl version in Ubuntu 24.04 LTS  
  (GitHub Actions runners)
- **No additional CI setup**: Avoids the overhead of installing newer Perl versions in CI, which  
  can be slow
- **Modern enough**: Provides all the modern Perl features we need for this application

You can check your Perl version with:

```bash
perl -v
```

If you need to install a newer Perl version, consider using [perlbrew](https://perlbrew.pl/) for  
local development.

## Installation

First, install system dependencies:

```bash
# On Ubuntu/Debian:
sudo apt install libssh2-1-dev
```

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

- **SSH development libraries** for Net::SSH2 Perl module:

  ```bash
  sudo apt install libssh2-1-dev
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

The project includes two types of tests:

### Unit Tests

Run unit tests that don't require virtualization:

```bash
./script/test unit
```

These tests can run in CI environments and test individual components in isolation.

### Integration Tests

Run integration tests that require multiple components to work together:

```bash
./script/test integration
```

It does not require any special setup and can be run on any machine with the necessary dependencies installed.

### Container Tests

Run tests that require Docker:

```bash
./script/test container
```

### E2E Tests

Run end-to-end tests that require local virtualization support:

```bash
./script/test e2e
```

**Requirements for E2E tests:**

- Local machine with KVM/libvirt support
- OpenTofu installed
- Required system tools: `qemu-system-x86_64`, `sshpass`
- SSH development libraries: `libssh2-1-dev`
- Cannot run in CI environments

### All Tests

Run both unit and E2E tests:

```bash
./script/test-all
```

E2E tests will be automatically skipped in CI environments or when virtualization tools are not available.
