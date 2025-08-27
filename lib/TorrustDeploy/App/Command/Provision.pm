package TorrustDeploy::App::Command::Provision;

use v5.38;

use TorrustDeploy::App -command;
use TorrustDeploy::OpenTofu;
use TorrustDeploy::Ansible;
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
    
    # Set up build directory
    my $work_dir = path('build');
    
    # Set up OpenTofu working directory and copy resolved templates
    my $tofu_dir = $work_dir->child('tofu');
    my $tofu = TorrustDeploy::OpenTofu->new();
    $tofu->copy_templates($tofu_dir);
    
    # Initialize OpenTofu
    $tofu->init($tofu_dir);
    
    # Apply OpenTofu configuration
    $tofu->apply($tofu_dir);
    
    # Get VM IP address
    my $vm_ip = $tofu->get_vm_ip($tofu_dir);
    STDOUT->flush();

    # Set up Ansible working directory and copy resolved templates
    my $ansible_dir = $work_dir->child('ansible');
    my $ansible = TorrustDeploy::Ansible->new();
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
