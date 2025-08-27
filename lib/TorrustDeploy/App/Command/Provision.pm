package TorrustDeploy::App::Command::Provision;

use v5.38;

use TorrustDeploy::App -command;
use TorrustDeploy::Provision::OpenTofu;
use TorrustDeploy::Provision::Ansible;
use TorrustDeploy::Infrastructure::SSH::Connection;
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
    
    # Create OpenTofu instance
    my $tofu = TorrustDeploy::Provision::OpenTofu->new();
    
    # Initialize OpenTofu
    $tofu->init($tofu_dir);
    
    # Apply OpenTofu configuration
    $tofu->apply($tofu_dir);
    
    # Get VM IP address
    my $vm_ip = $tofu->get_vm_ip($tofu_dir);
    
    # Create SSH connection
    my $ssh_connection = TorrustDeploy::Infrastructure::SSH::Connection->new(host => $vm_ip);
    
    # Wait for cloud-init completion
    $self->_wait_for_cloud_init($ssh_connection);
    
    # Force reconnection after cloud-init completes (VM reboots during cloud-init)
    say "🔄 Refreshing SSH connection after cloud-init reboot...";
    STDOUT->flush();
    $ssh_connection->force_reconnect();
    
    # Verify SSH key authentication after cloud-init completes
    $self->_verify_ssh_key_auth($ssh_connection);
    
    # Run Ansible post-provision verification (experimental)
    $self->_run_ansible_verification($vm_ip, $work_dir);
    
    # Show final summary
    $self->_show_final_summary($ssh_connection);
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

sub _wait_for_cloud_init {
    my ($self, $ssh_connection) = @_;
    
    say "Waiting for cloud-init to complete...";
    say "This may take several minutes while packages are installed and configured.";
    STDOUT->flush();
    
    my $completion_file = "/var/lib/cloud/torrust-setup-complete";
    my $max_attempts = 360; # 30 minutes with 5-second intervals
    my $attempt = 0;
    my $ssh_connected = 0;
    my $cloud_init_success = 0;
    
    # Step 1: Wait until SSH connection is available (for password auth to check cloud-init)
    say "⏳ Waiting for SSH service to become available...";
    STDOUT->flush();
    
    while ($attempt < $max_attempts && !$ssh_connected) {
        $attempt++;
        
        if ($ssh_connection->test_password_connection()) {
            $ssh_connected = 1;
            say "✅ SSH password connection established to " . $ssh_connection->host;
            STDOUT->flush();
        } else {
            if ($attempt % 6 == 0) { # Every 30 seconds
                say "  [Waiting for SSH connection... ${attempt}0s elapsed]";
                STDOUT->flush();
            }
            sleep(5);
        }
    }
    
    if (!$ssh_connected) {
        say "❌ Failed to establish SSH connection to " . $ssh_connection->host . " after " . ($max_attempts * 5 / 60) . " minutes";
        STDOUT->flush();
        $self->_print_cloud_init_logs($ssh_connection);
        die "SSH connection failed";
    }
    
    # Step 2: Wait until cloud-init completion marker is created
    say "⏳ Waiting for cloud-init to complete...";
    STDOUT->flush();
    
    $attempt = 0;
    my $consecutive_ssh_failures = 0;
    while ($attempt < $max_attempts) {
        $attempt++;
        
        my $result = $ssh_connection->execute_command("test -f $completion_file");
        
        # Debug: Always show result details when exit code is 0
        if ($result->exit_code == 0) {
            say "  [DEBUG] File exists! Exit code: " . $result->exit_code . 
                ", Success method: " . ($result->success ? 'true' : 'false') . 
                ", Output: '" . ($result->output // 'EMPTY') . "'";
            STDOUT->flush();
        }
        
        if ($result->success) {
            say "✅ Cloud-init setup completed successfully!";
            STDOUT->flush();
            
            # Show completion message
            my $completion_result = $ssh_connection->execute_command("cat $completion_file");
            if ($completion_result->success && $completion_result->output) {
                chomp(my $output = $completion_result->output);
                say "📅 Completion marker: " . $output;
                STDOUT->flush();
            }
            $cloud_init_success = 1;
            last;
        } else {
            # Track consecutive SSH failures (exit code 255)
            if ($result->exit_code == 255) {
                $consecutive_ssh_failures++;
                # If we have too many consecutive SSH failures, try to re-establish password connection
                if ($consecutive_ssh_failures >= 12) { # 1 minute of consecutive failures
                    say "⚠️ SSH connection lost, attempting to re-establish (VM may be rebooting)...";
                    say "  [Waiting 30s for VM to complete reboot...]";
                    STDOUT->flush();
                    sleep(30); # Give VM time to fully reboot
                    
                    # Try to re-establish password connection (VM might have rebooted)
                    my $reconnect_attempts = 0;
                    while ($reconnect_attempts < 12 && !$ssh_connection->test_password_connection()) {
                        $reconnect_attempts++;
                        say "  [Reconnection attempt $reconnect_attempts/12...]";
                        STDOUT->flush();
                        sleep(15); # Wait longer between attempts
                    }
                    
                    if ($ssh_connection->test_password_connection()) {
                        say "✅ SSH connection re-established!";
                        STDOUT->flush();
                        $consecutive_ssh_failures = 0; # Reset counter after successful reconnection
                    } else {
                        say "❌ Failed to re-establish SSH connection after VM reboot.";
                        say "  [DEBUG] Last error: " . $result->output;
                        STDOUT->flush();
                        last;
                    }
                }
            } else {
                # Reset counter for non-SSH failures (normal file-not-found errors)
                $consecutive_ssh_failures = 0;
            }
            
            # Debug: Show why the command failed
            if ($attempt % 6 == 0) { # Every 30 seconds
                my $elapsed_seconds = $attempt * 5;
                say "   [DEBUG ${elapsed_seconds}s] File check failed - Exit code: " . $result->exit_code . 
                    " (this is normal until cloud-init completes)";
                if ($consecutive_ssh_failures > 0) {
                    say "    [SSH failures: $consecutive_ssh_failures consecutive]";
                }
                STDOUT->flush();
            }
        }
        
        # Show progress indicator every 2 minutes
        if ($attempt % 24 == 0) {
            my $elapsed_minutes = int($attempt * 5 / 60);
            say "  [Cloud-init still running... ${elapsed_minutes} minutes elapsed]";
            STDOUT->flush();
        }
        
        sleep(5);
    }
    
    if (!$cloud_init_success) {
        say "❌ Timeout waiting for cloud-init to complete on " . $ssh_connection->host . " after " . ($max_attempts * 5 / 60) . " minutes";
        STDOUT->flush();
        $self->_print_cloud_init_logs($ssh_connection);
        die "Cloud-init timeout";
    }
}

sub _show_final_summary {
    my ($self, $ssh_connection) = @_;
    
    say "📦 Final system summary:";
    STDOUT->flush();
    
    # Try multiple approaches to detect Docker
    my $docker_result;
    my $docker_method = "unknown";
    
    # Method 1: Try with newgrp (preferred for group activation)
    $docker_result = $ssh_connection->execute_command('newgrp docker -c "docker --version" 2>&1');
    if ($docker_result->success) {
        $docker_method = "newgrp";
    } else {
        # Method 2: Try with sudo (fallback)
        $docker_result = $ssh_connection->execute_command('sudo docker --version 2>&1');
        if ($docker_result->success) {
            $docker_method = "sudo";
        } else {
            # Method 3: Try direct command (may fail due to group membership)
            $docker_result = $ssh_connection->execute_command('docker --version 2>&1');
            if ($docker_result->success) {
                $docker_method = "direct";
            }
        }
    }
    
    my $docker_version;
    if ($docker_result->success) {
        $docker_version = $docker_result->output . " (via $docker_method)";
    } else {
        $docker_version = "Docker not available - all methods failed";
    }
    
    chomp $docker_version if $docker_version;
    say "   Docker: $docker_version";
    STDOUT->flush();
    
    # Check firewall status
    
    my $ufw_result = $ssh_connection->execute_command('sudo ufw status | head -1');
    my $ufw_status = $ufw_result->success ? $ufw_result->output : "UFW not available";
    chomp $ufw_status if $ufw_status;
    say "   Firewall: $ufw_status" if $ufw_status;
    STDOUT->flush();

    say "Provisioning completed successfully!";
    say "VM is ready at IP: " . $ssh_connection->host;
    STDOUT->flush();
}

sub _print_cloud_init_logs {
    my ($self, $ssh_connection) = @_;
    
    say "📄 Cloud-init logs (for debugging):";
    
    # Print cloud-init-output.log
    say "=== /var/log/cloud-init-output.log ===";
    my $output_result = $ssh_connection->execute_command_with_sudo('cat /var/log/cloud-init-output.log');
    if ($output_result->success) {
        print $output_result->output;
    } else {
        say "Cloud-init output log not available";
    }
    
    say "=== /var/log/cloud-init.log ===";
    my $main_result = $ssh_connection->execute_command_with_sudo('cat /var/log/cloud-init.log');
    if ($main_result->success) {
        print $main_result->output;
    } else {
        say "Cloud-init main log not available";
    }
}

sub _verify_ssh_key_auth {
    my ($self, $ssh_connection) = @_;
    
    say "🔑 Checking SSH key authentication...";
    STDOUT->flush();
    
    # SSH authentication might need time to fully stabilize after cloud-init reboot
    # Try with progressive delays: immediate, 5s, 10s, 15s
    my @retry_delays = (0, 5, 10, 15);
    
    for my $attempt (0..$#retry_delays) {
        if ($attempt > 0) {
            my $delay = $retry_delays[$attempt];
            say "⏳ Waiting ${delay}s before retry attempt " . ($attempt + 1) . "...";
            STDOUT->flush();
            sleep $delay;
        }
        
        # Create a fresh SSH connection for key authentication test
        # This ensures we don't have any state issues from cloud-init monitoring
        my $fresh_ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(
            host => $ssh_connection->host
        );
        
        if ($fresh_ssh->test_key_connection()) {
            say "✅ SSH key authentication is working correctly!";
            say "You can now connect using: ssh -i " . $fresh_ssh->ssh_key_path . " " . $fresh_ssh->username . "@" . $fresh_ssh->host;
            STDOUT->flush();
            return;
        }
        
        if ($attempt < $#retry_delays) {
            say "⚠️ SSH key authentication failed, will retry...";
            STDOUT->flush();
        }
    }
    
    # All retries failed
    say "❌ SSH key authentication failed after all retries";
    STDOUT->flush();
    $self->_print_cloud_init_logs($ssh_connection);
    die "SSH key authentication failed";
}

sub _run_ansible_verification {
    my ($self, $vm_ip, $work_dir) = @_;
    
    say "";
    say "🎭 Starting Ansible post-provision verification (experimental)...";
    STDOUT->flush();
    
    # Set up Ansible working directory
    my $ansible_dir = $work_dir->child('ansible');
    
    # Create Ansible instance and set up configuration
    my $ansible = TorrustDeploy::Provision::Ansible->new();
    $ansible->copy_templates_and_generate_inventory($vm_ip, $ansible_dir);
    
    # Run verification playbook
    $ansible->run_verification($ansible_dir);
    
    say "";
}

1;

__END__

=head1 NAME

TorrustDeploy::App::Command::Provision - Provision Torrust Tracker VM

=head1 DESCRIPTION

Provisions a Torrust Tracker virtual machine using OpenTofu with the libvirt provider.
Creates a minimal Ubuntu 24.04 LTS VM, waits for IP assignment, and monitors cloud-init 
completion via SSH.

=head1 USAGE

    torrust-deploy provision

=head1 REQUIREMENTS

- OpenTofu installed
- Ansible installed
- libvirt/KVM installed and running
- qemu-system-x86_64
- sshpass installed (for password authentication during cloud-init monitoring)
- Testing SSH key pair (~/.ssh/testing_rsa)
- Default libvirt storage pool configured
- Template files in templates/ directory (main.tf, cloud-init.yml, ansible/)

=cut
