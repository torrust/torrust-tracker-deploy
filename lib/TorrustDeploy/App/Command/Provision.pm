package TorrustDeploy::App::Command::Provision;

use v5.38;

use TorrustDeploy::App -command;
use TorrustDeploy::Provision::OpenTofu;
use TorrustDeploy::Provision::Ansible;
use Path::Tiny qw(path);
use File::Spec;
use Time::HiRes qw(sleep);
use JSON;

sub abstract { "Provision Torrust Tracker VM using OpenTofu" }

sub description { 
    return <<'END_DESCRIPTION';
Provision a Torrust Tracker virtual machine using OpenTofu with libvirt provider.

This command will:
1. Initialize OpenTofu if needed
2. Copy configuration templates to the working directory
3. Create a VM with hardcoded minimal configuration
4. Wait for cloud-init completion using Ansible
5. Run post-provision verification via Ansible
6. Restart the VM after successful verification

The VM will be created locally using libvirt/KVM.
Cloud-init handles initial setup, Ansible manages the orchestration.
END_DESCRIPTION
}

sub execute {
    my ($self, $opt, $args) = @_;
    
    say "Starting Torrust Tracker provisioning...";
    
    # Set up working directories
    my $work_dir = path('build');
    my $templates_dir = path('templates/provision');
    my $tofu_dir = $work_dir->child('tofu');
    
    # Ensure tofu directory exists
    $tofu_dir->mkpath unless $tofu_dir->exists;
    
    # Copy templates to working directory
    $self->_copy_templates($templates_dir, $tofu_dir);
    
    # Create OpenTofu instance
    my $tofu = TorrustDeploy::Provision::OpenTofu->new();
    
    # Initialize OpenTofu
    $tofu->init($tofu_dir);
    
    # Apply OpenTofu configuration
    $tofu->apply($tofu_dir);
    
    # Get VM IP address
    my $vm_ip = $tofu->get_vm_ip($tofu_dir);
    STDOUT->flush();

    # Set up Ansible working directory and copy templates
    my $ansible_dir = $work_dir->child('ansible');
    my $ansible = TorrustDeploy::Provision::Ansible->new();
    $ansible->copy_templates_and_generate_inventory($vm_ip, $ansible_dir);

    # Wait for cloud-init completion using Ansible
    $ansible->wait_for_cloud_init($ansible_dir);

    # Run Ansible post-provision verification
    $ansible->run_verification($ansible_dir);

    # Restart VM after verification
    $ansible->restart_vm($ansible_dir);

    # Final completion message
    say "";
    say "✅ Provisioning completed successfully!";
    say "VM is ready at IP: " . $vm_ip;
    say "You can connect using: ssh -i ~/.ssh/testing_rsa torrust@" . $vm_ip;
    say "VM has been restarted and is ready for production use!";
    STDOUT->flush();
}

sub _copy_templates {
    my ($self, $templates_dir, $tofu_dir) = @_;
    
    say "Copying OpenTofu templates...";
    
    # Check if templates directory exists
    unless ($templates_dir->exists) {
        die "Templates directory not found: $templates_dir";
    }
    
    # Copy main.tf template
    my $main_tf_template = $templates_dir->child('tofu/providers/libvirt/main.tf');
    my $main_tf_dest = $tofu_dir->child('main.tf');
    
    unless ($main_tf_template->exists) {
        die "Template file not found: $main_tf_template";
    }
    
    $main_tf_template->copy($main_tf_dest);
    say "Copied: $main_tf_template -> $main_tf_dest";
    
    # Copy cloud-init.yml template
    my $cloud_init_template = $templates_dir->child('cloud-init.yml');
    my $cloud_init_dest = $tofu_dir->child('cloud-init.yml');
    
    unless ($cloud_init_template->exists) {
        die "Template file not found: $cloud_init_template";
    }
    
    $cloud_init_template->copy($cloud_init_dest);
    say "Copied: $cloud_init_template -> $cloud_init_dest";
    
    say "Templates copied successfully.";
}

1;

__END__

=head1 NAME

TorrustDeploy::App::Command::Provision - Provision Torrust Tracker VM

=head1 DESCRIPTION

Provisions a Torrust Tracker virtual machine using OpenTofu with the libvirt provider.
Creates a minimal Ubuntu 24.04 LTS VM, waits for cloud-init completion using Ansible,
runs post-provision verification, and performs a clean VM restart.

=head1 USAGE

    torrust-deploy provision

=head1 REQUIREMENTS

- OpenTofu installed
- Ansible installed (with community.general collection for cloud_init module)
- libvirt/KVM installed and running
- qemu-system-x86_64
- Testing SSH key pair (~/.ssh/testing_rsa)
- Default libvirt storage pool configured
- Template files in templates/ directory (main.tf, cloud-init.yml, ansible/)

=cut
