# Torrust Deploy - Rust Implementation

A modern Rust implementation of the Torrust Tracker Deployment Tool for deploying
Torrust Tracker to cloud providers using OpenTofu/Terraform and cloud-init for VM
configuration.

## Overview

This is a Rust rewrite of the original Perl application, focusing on the core functionality:

- OpenTofu/Terraform wrapper for infrastructure provisioning
- Ansible integration for post-provision configuration
- Template management and processing
- Command-line interface for deployment operations

**Note**: This implementation does not include the SSH connection management modules
from the Perl version, as they are not used in the main application workflow.

## Requirements

- **Rust 1.70+** - For modern async/await and other language features
- **OpenTofu** - Infrastructure provisioning ([Download from opentofu.org](https://opentofu.org/docs/intro/install/))
- **Ansible** - Configuration management and orchestration
- **libvirt/KVM** - For local VM provisioning (if using libvirt provider)

### System Dependencies

On Ubuntu/Debian:

```bash
sudo apt install ansible libvirt-daemon-system qemu-system-x86_64
```

## Installation

1. **Build from source:**

   ```bash
   cd rust
   cargo build --release
   ```

2. **The binary will be available at:**

   ```bash
   ./target/release/torrust-deploy
   ```

## Usage

### Help

```bash
./target/release/torrust-deploy --help
```

### Provision VM

```bash
./target/release/torrust-deploy provision
```

This command will:

1. Copy OpenTofu configuration templates
2. Initialize OpenTofu if needed
3. Create a VM with the configured settings
4. Wait for cloud-init completion via Ansible
5. Run post-provision verification
6. Restart the VM after successful verification

### Command Options

```bash
./target/release/torrust-deploy provision --help
```

Available options:

- `--build-dir <DIR>` - Working directory for build artifacts (default: "build")
- `--verbose` - Enable verbose output

## Development

### Build

```bash
cargo build
```

### Run Tests

```bash
cargo test
```

### Run with Logs

```bash
RUST_LOG=debug cargo run -- provision
```

### Code Quality

```bash
# Format code
cargo fmt

# Run linter
cargo clippy

# Check for common issues
cargo audit
```

## Architecture

### Module Structure

```text
src/
├── main.rs                    # Application entry point
├── lib.rs                     # Library root
├── cli/                       # Command-line interface
│   ├── mod.rs
│   └── commands/
│       ├── mod.rs
│       └── provision.rs       # Provision command implementation
├── providers/                 # External tool integrations
│   ├── mod.rs
│   ├── opentofu.rs           # OpenTofu/Terraform wrapper
│   └── ansible.rs            # Ansible wrapper
├── templates/                 # Template management
│   └── mod.rs
└── error.rs                  # Error handling
```

### Key Components

- **CLI Framework**: Uses `clap` for argument parsing and subcommands
- **Async Runtime**: Built on `tokio` for async/await operations
- **Error Handling**: Uses `thiserror` for structured error types
- **Process Execution**: Executes external commands via `tokio::process`
- **Template Processing**: File copying and variable substitution
- **Logging**: Structured logging with `tracing`

## Differences from Perl Version

### Removed Components

- **SSH Connection Management**: The `TorrustDeploy::SSH::*` modules are not
  implemented as they are unused in the main application

### Improvements

- **Type Safety**: Compile-time error checking vs runtime errors
- **Performance**: Compiled binary with better memory usage
- **Async Operations**: Native async/await support for better concurrency
- **Modern Tooling**: Cargo package manager, rustfmt, clippy
- **Error Handling**: Structured error types with context

### Maintained Features

- **Same CLI Interface**: Compatible command structure and options
- **Template System**: Same template files and processing logic
- **OpenTofu Integration**: Identical workflow and commands
- **Ansible Integration**: Same playbooks and orchestration
- **Build Artifacts**: Same directory structure and outputs

## Testing

The test suite includes:

### Unit Tests

```bash
cargo test
```

### Integration Tests

Tests that verify component interactions:

```bash
cargo test --test '*'
```

### Manual Testing

For full end-to-end testing with real infrastructure:

```bash
# Ensure you have the required templates from the parent directory
ln -sf ../templates .

# Run provision command
./target/release/torrust-deploy provision
```

## Configuration

The application uses the same template files as the Perl version:

- `templates/main.tf` - OpenTofu configuration
- `templates/tofu/cloud-init.yml` - Cloud-init configuration
- `templates/ansible/` - Ansible playbooks and configuration

## Troubleshooting

### Common Issues

1. **Missing templates**: Ensure template files exist in the `templates/` directory
2. **OpenTofu not found**: Install OpenTofu and ensure it's in your PATH
3. **Ansible not found**: Install Ansible and required collections
4. **Permission denied**: Ensure proper file permissions for SSH keys and templates

### Debug Mode

Run with debug logging to see detailed execution:

```bash
RUST_LOG=debug ./target/release/torrust-deploy provision
```

### Log Levels

- `error` - Only errors
- `warn` - Warnings and errors
- `info` - Information, warnings, and errors (default)
- `debug` - All logs including debug information
- `trace` - Very verbose logging

## License

This software is licensed under the MIT License. See LICENSE file for details.
