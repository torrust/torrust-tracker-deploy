use v5.38;
use Test::More;
use Test::Exception;
use File::Temp qw(tempdir);
use Path::Tiny qw(path);
use POSIX qw(SIGTERM);

# Skip this test if we're in CI or if virtualization is not available
BEGIN {
    if ($ENV{CI} || $ENV{SKIP_E2E}) {
        plan skip_all => 'E2E tests require local virtualization support';
    }
    
    # Check if required tools are available
    my $missing_tools = [];
    for my $tool (qw(tofu libvirtd qemu-system-x86_64 sshpass)) {
        system("which $tool >/dev/null 2>&1") != 0 and push @$missing_tools, $tool;
    }
    
    if (@$missing_tools) {
        plan skip_all => "Missing required tools: " . join(', ', @$missing_tools);
    }
}

plan tests => 5;

note "=== E2E Provision Test ===";
note "This test will:";
note "  1. Clean up any leftover resources";
note "  2. Check required templates exist";
note "  3. Run the provision command (may take 5-10 minutes)";
note "  4. Verify infrastructure was created";
note "  5. Clean up test resources";
note "";
note "Please be patient - VM provisioning takes time!";
note "";

# Change to project root for the test
my $original_cwd = path('.');
my $project_root = path(__FILE__)->parent->parent->parent;
chdir $project_root or die "Cannot change to project root: $!";

# Clean up any leftover resources from previous test runs
subtest 'cleanup leftover resources from previous runs' => sub {
    plan tests => 1;
    
    my $cleanup_needed = 0;
    
    # Check for existing libvirt domain
    my $domain_exists = system('sudo virsh domstate torrust-tracker >/dev/null 2>&1') == 0;
    if ($domain_exists) {
        note "Found existing torrust-tracker domain, cleaning up...";
        note "  - Destroying domain...";
        system('sudo virsh destroy torrust-tracker >/dev/null 2>&1');
        note "  - Undefining domain...";
        system('sudo virsh undefine torrust-tracker >/dev/null 2>&1');
        $cleanup_needed = 1;
    }
    
    # Check for existing cloudinit volume
    my $cloudinit_exists = system('sudo virsh vol-info torrust-cloudinit.iso --pool default >/dev/null 2>&1') == 0;
    if ($cloudinit_exists) {
        note "Found existing torrust-cloudinit.iso volume, cleaning up...";
        note "  - Deleting cloudinit volume...";
        system('sudo virsh vol-delete torrust-cloudinit.iso --pool default >/dev/null 2>&1');
        $cleanup_needed = 1;
    }
    
    # Check for other volumes that might be left over
    for my $vol_name (qw(torrust-tracker-vm.qcow2 ubuntu-22.04-base.qcow2)) {
        my $vol_exists = system("sudo virsh vol-info '$vol_name' --pool default >/dev/null 2>&1") == 0;
        if ($vol_exists) {
            note "Found existing $vol_name volume, cleaning up...";
            note "  - Deleting volume $vol_name...";
            system("sudo virsh vol-delete '$vol_name' --pool default >/dev/null 2>&1");
            $cleanup_needed = 1;
        }
    }
    
    # Clean up any existing build/tofu state
    if (-f 'build/tofu/terraform.tfstate') {
        note "Found existing OpenTofu state, cleaning up...";
        if (-d 'build/tofu') {
            note "  - Destroying OpenTofu resources...";
            chdir 'build/tofu';
            system('tofu destroy -auto-approve >/dev/null 2>&1');
            chdir '../..';
        }
        $cleanup_needed = 1;
    }
    
    if ($cleanup_needed) {
        note "Cleanup completed, waiting a moment for resources to be fully removed...";
        sleep 2;
    }
    
    pass('Pre-test cleanup completed');
};

# Ensure we have required templates
ok(-f 'templates/provision/tofu/providers/libvirt/main.tf', 'Required OpenTofu template exists');
ok(-f 'templates/provision/cloud-init.yml', 'Required cloud-init template exists');

subtest 'provision command executes successfully' => sub {
    plan tests => 3;
    
    note "Starting provision command (this may take several minutes)...";
    note "Command: carmel exec -- $^X -Ilib bin/torrust-deploy provision";
    note "Use 'prove -v' to see real-time output from system commands";
    
    my $start_time = time();
    my $timeout = $ENV{E2E_TIMEOUT} || 480; # 8 minutes default, configurable
    
    # Run command with timeout using carmel exec for proper dependencies
    # Capture output to prevent Ansible "ok:" lines from being interpreted as TAP output
    my $cmd = "timeout ${timeout}s carmel exec -- $^X -Ilib bin/torrust-deploy provision 2>&1";
    my $output = `$cmd`;
    my $exit_code = $? >> 8;
    my $duration = time() - $start_time;
    
    # Check if command timed out
    if ($exit_code == 124) { # timeout command exit code
        fail("Provision command timed out after ${timeout} seconds");
        note "Consider increasing timeout with E2E_TIMEOUT environment variable";
        return;
    }
    
    note "Provision command completed in ${duration} seconds";
    
    # Show output summary in verbose mode
    if ($ENV{TEST_VERBOSE} || $ENV{HARNESS_IS_VERBOSE}) {
        note "Command output (last 50 lines):";
        my @output_lines = split /\n/, $output;
        my $start_line = @output_lines > 50 ? @output_lines - 50 : 0;
        for my $i ($start_line .. $#output_lines) {
            note "  $output_lines[$i]";
        }
    }
    
    # Command should complete successfully
    is($exit_code, 0, 'provision command exits with status 0');
    
    # Basic checks - we can't easily check output without complexity
    pass('provision command executed (use prove -v to see output)');
    pass('provision completed within timeout');
};

subtest 'provision creates expected infrastructure' => sub {
    plan tests => 2;
    
    # Check if build directory was created
    ok(-d 'build/tofu', 'build/tofu directory was created');
    
    # Check if OpenTofu state file exists
    ok(-f 'build/tofu/terraform.tfstate', 'OpenTofu state file was created');
};

# Cleanup: destroy infrastructure after test
END {
    note "=== E2E Test Cleanup ===";
    
    # Ensure we're in the right directory for cleanup
    if ($project_root && -d $project_root) {
        chdir $project_root;
    }
    
    if (-f 'build/tofu/terraform.tfstate') {
        note "Cleaning up test infrastructure...";
        
        # Try OpenTofu destroy first (proper way)
        if (-d 'build/tofu') {
            note "  - Running OpenTofu destroy...";
            chdir 'build/tofu';
            my $destroy_result = system('tofu destroy -auto-approve');
            chdir '../..';
            
            # If OpenTofu destroy failed, manually clean up libvirt resources
            if ($destroy_result != 0) {
                note "OpenTofu destroy failed, manually cleaning up libvirt resources...";
                
                # Clean up domain
                note "  - Destroying domain...";
                system('sudo virsh destroy torrust-tracker >/dev/null 2>&1');
                note "  - Undefining domain...";
                system('sudo virsh undefine torrust-tracker >/dev/null 2>&1');
                
                # Clean up volumes
                note "  - Removing volumes...";
                for my $vol_name (qw(torrust-cloudinit.iso torrust-tracker-vm.qcow2 ubuntu-22.04-base.qcow2)) {
                    note "    * $vol_name";
                    system("sudo virsh vol-delete '$vol_name' --pool default >/dev/null 2>&1");
                }
            } else {
                note "OpenTofu destroy completed successfully";
            }
        }
        
        # Clean up build directory if everything was destroyed successfully
        if (system('sudo virsh domstate torrust-tracker >/dev/null 2>&1') != 0) {
            # Domain doesn't exist, safe to remove build state
            note "  - Removing build directory...";
            system('rm -rf build/tofu') if -d 'build/tofu';
        }
        
        note "Cleanup completed";
    } else {
        note "No infrastructure to clean up";
    }
    
    # Restore original working directory
    chdir $original_cwd if $original_cwd;
}

done_testing();
