package TorrustDeploy::App::Command::provision;

use strict;
use warnings;
use v5.20;

use TorrustDeploy::App -command;
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
4. Wait for IP assignment and cloud-init completion
5. Monitor cloud-init progress via SSH

The VM will be created locally using libvirt/KVM.
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
    
    # Initialize OpenTofu
    $self->_run_tofu_init($tofu_dir);
    
    # Apply OpenTofu configuration
    $self->_run_tofu_apply($tofu_dir);
    
    # Get VM IP address
    my $vm_ip = $self->_get_vm_ip($tofu_dir);
    
    # Wait for cloud-init completion
    $self->_wait_for_cloud_init($vm_ip);
    
    # Verify SSH key authentication after cloud-init completes
    $self->_verify_ssh_key_auth($vm_ip);
    
    # Show final summary
    $self->_show_final_summary($vm_ip);
    
    say "Provisioning completed successfully!";
    say "VM is ready at IP: $vm_ip";
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

sub _run_tofu_init {
    my ($self, $tofu_dir) = @_;
    
    say "Initializing OpenTofu...";
    
    my $result = system("cd '$tofu_dir' && tofu init");
    if ($result != 0) {
        die "OpenTofu init failed with exit code: $result";
    }
    
    say "OpenTofu initialized successfully.";
}

sub _run_tofu_apply {
    my ($self, $tofu_dir) = @_;
    
    say "Applying OpenTofu configuration...";
    say "This may take a few minutes to download the base image and create the VM...";
    
    my $result = system("cd '$tofu_dir' && tofu apply -auto-approve");
    if ($result != 0) {
        die "OpenTofu apply failed with exit code: $result";
    }
    
    say "OpenTofu apply completed successfully.";
}

sub _get_vm_ip {
    my ($self, $tofu_dir) = @_;
    
    say "Getting VM IP address...";
    
    my $output = `cd '$tofu_dir' && tofu output -json`;
    if ($? != 0) {
        die "Failed to get OpenTofu outputs";
    }
    
    my $outputs = decode_json($output);
    my $vm_ip = $outputs->{vm_ip}{value};
    
    unless ($vm_ip) {
        die "Could not retrieve VM IP address from OpenTofu outputs";
    }
    
    say "VM IP address: $vm_ip";
    return $vm_ip;
}

sub _wait_for_cloud_init {
    my ($self, $vm_ip) = @_;
    
    say "Waiting for cloud-init to complete...";
    say "This may take several minutes while packages are installed and configured.";
    
    my $completion_file = "/var/lib/cloud/torrust-setup-complete";
    my $max_attempts = 360; # 30 minutes with 5-second intervals
    my $attempt = 0;
    my $ssh_connected = 0;
    my $cloud_init_success = 0;
    
    # Step 1: Wait until SSH connection is available (for password auth to check cloud-init)
    say "⏳ Waiting for SSH service to become available...";
    
    while ($attempt < $max_attempts && !$ssh_connected) {
        $attempt++;
        
        my $ssh_test = system("timeout 5 sshpass -p 'torrust123' ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null torrust\@$vm_ip 'echo \"SSH connected\"' >/dev/null 2>&1");
        if ($ssh_test == 0) {
            $ssh_connected = 1;
            say "✅ SSH password connection established to $vm_ip";
        } else {
            if ($attempt % 6 == 0) { # Every 30 seconds
                say "  [Waiting for SSH connection... ${attempt}0s elapsed]";
            }
            sleep(5);
        }
    }
    
    if (!$ssh_connected) {
        say "❌ Failed to establish SSH connection to $vm_ip after " . ($max_attempts * 5 / 60) . " minutes";
        $self->_print_cloud_init_logs($vm_ip);
        die "SSH connection failed";
    }
    
    # Step 2: Wait until cloud-init completion marker is created
    say "⏳ Waiting for cloud-init to complete...";
    
    $attempt = 0;
    while ($attempt < $max_attempts) {
        $attempt++;
        
        my $check_result = system("timeout 10 sshpass -p 'torrust123' ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null torrust\@$vm_ip 'test -f $completion_file' >/dev/null 2>&1");
        
        if ($check_result == 0) {
            say "✅ Cloud-init setup completed successfully!";
            
            # Show completion message
            my $completion_content = `timeout 10 sshpass -p 'torrust123' ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null torrust\@$vm_ip 'cat $completion_file' 2>/dev/null`;
            if ($completion_content) {
                chomp $completion_content;
                say "📅 Completion marker: $completion_content";
            }
            $cloud_init_success = 1;
            last;
        }
        
        # Show progress indicator every 2 minutes
        if ($attempt % 24 == 0) {
            my $elapsed_minutes = int($attempt * 5 / 60);
            say "  [Cloud-init still running... ${elapsed_minutes} minutes elapsed]";
        }
        
        sleep(5);
    }
    
    if (!$cloud_init_success) {
        say "❌ Timeout waiting for cloud-init to complete on $vm_ip after " . ($max_attempts * 5 / 60) . " minutes";
        $self->_print_cloud_init_logs($vm_ip);
        die "Cloud-init timeout";
    }
}

sub _show_final_summary {
    my ($self, $vm_ip) = @_;
    
    say "📦 Final system summary:";
    
    my $docker_version = `timeout 10 sshpass -p 'torrust123' ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null torrust\@$vm_ip 'docker --version 2>/dev/null || echo "Docker not available"' 2>/dev/null`;
    chomp $docker_version if $docker_version;
    say "   Docker: $docker_version" if $docker_version;
    
    my $ufw_status = `timeout 10 sshpass -p 'torrust123' ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null torrust\@$vm_ip 'ufw status 2>/dev/null | head -1 || echo "UFW not available"' 2>/dev/null`;
    chomp $ufw_status if $ufw_status;
    say "   Firewall: $ufw_status" if $ufw_status;

    say "Provisioning completed successfully!";
    say "VM is ready at IP: $vm_ip";
}

sub _print_cloud_init_logs {
    my ($self, $vm_ip) = @_;
    
    say "📄 Cloud-init logs (for debugging):";
    
    # Print cloud-init-output.log
    say "=== /var/log/cloud-init-output.log ===";
    my $output_log = `timeout 30 sshpass -p 'torrust123' ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null torrust\@$vm_ip 'sudo cat /var/log/cloud-init-output.log 2>/dev/null || echo "Log file not available"' 2>/dev/null`;
    if ($output_log && $output_log !~ /^Log file not available/) {
        print $output_log;
    } else {
        say "Cloud-init output log not available";
    }
    
    say "=== /var/log/cloud-init.log ===";
    my $main_log = `timeout 30 sshpass -p 'torrust123' ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null torrust\@$vm_ip 'sudo cat /var/log/cloud-init.log 2>/dev/null || echo "Log file not available"' 2>/dev/null`;
    if ($main_log && $main_log !~ /^Log file not available/) {
        print $main_log;
    } else {
        say "Cloud-init main log not available";
    }
}

sub _verify_ssh_key_auth {
    my ($self, $vm_ip) = @_;
    
    say "🔑 Checking SSH key authentication...";
    
    my $ssh_key_path = "$ENV{HOME}/.ssh/testing_rsa";
    
    # Test SSH key authentication
    my $result = system("timeout 10 ssh -i '$ssh_key_path' -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no torrust\@$vm_ip 'echo \"SSH key authentication successful\"' >/dev/null 2>&1");
    
    if ($result == 0) {
        say "✅ SSH key authentication is working correctly!";
        say "You can now connect using: ssh -i ~/.ssh/testing_rsa torrust\@$vm_ip";
    } else {
        say "❌ SSH key authentication failed";
        $self->_print_cloud_init_logs($vm_ip);
        die "SSH key authentication failed";
    }
}

1;

__END__

=head1 NAME

TorrustDeploy::App::Command::provision - Provision Torrust Tracker VM

=head1 DESCRIPTION

Provisions a Torrust Tracker virtual machine using OpenTofu with the libvirt provider.
Creates a minimal Ubuntu 24.04 LTS VM, waits for IP assignment, and monitors cloud-init 
completion via SSH.

=head1 USAGE

    torrust-deploy provision

=head1 REQUIREMENTS

- OpenTofu installed
- libvirt/KVM installed and running
- qemu-system-x86_64
- sshpass installed (for password authentication during cloud-init monitoring)
- Testing SSH key pair (~/.ssh/testing_rsa)
- Default libvirt storage pool configured
- Template files in templates/ directory (main.tf, cloud-init.yml)

=cut
