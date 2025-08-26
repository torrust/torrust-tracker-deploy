use v5.38;
use Test::More;
use Test::Exception;
use Capture::Tiny qw(capture);
use File::Temp qw(tempdir);
use Path::Tiny qw(path);

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
        system('sudo virsh destroy torrust-tracker >/dev/null 2>&1');
        system('sudo virsh undefine torrust-tracker >/dev/null 2>&1');
        $cleanup_needed = 1;
    }
    
    # Check for existing cloudinit volume
    my $cloudinit_exists = system('sudo virsh vol-info torrust-cloudinit.iso --pool default >/dev/null 2>&1') == 0;
    if ($cloudinit_exists) {
        note "Found existing torrust-cloudinit.iso volume, cleaning up...";
        system('sudo virsh vol-delete torrust-cloudinit.iso --pool default >/dev/null 2>&1');
        $cleanup_needed = 1;
    }
    
    # Check for other volumes that might be left over
    for my $vol_name (qw(torrust-tracker-vm.qcow2 ubuntu-22.04-base.qcow2)) {
        my $vol_exists = system("sudo virsh vol-info '$vol_name' --pool default >/dev/null 2>&1") == 0;
        if ($vol_exists) {
            note "Found existing $vol_name volume, cleaning up...";
            system("sudo virsh vol-delete '$vol_name' --pool default >/dev/null 2>&1");
            $cleanup_needed = 1;
        }
    }
    
    # Clean up any existing build/tofu state
    if (-f 'build/tofu/terraform.tfstate') {
        note "Found existing OpenTofu state, cleaning up...";
        if (-d 'build/tofu') {
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
    
    # Capture command output
    my ($stdout, $stderr, $exit_code) = capture {
        system($^X, '-Ilib', 'bin/torrust-deploy', 'provision');
    };
    
    # Command should complete successfully
    is($exit_code, 0, 'provision command exits with status 0');
    
    # Output should contain success message
    like($stdout, qr/Provisioning completed successfully!/, 'output contains success message');
    
    # Should not have critical errors in stderr
    unlike($stderr, qr/(?:fatal|error|died)/i, 'no critical errors in stderr');
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
    # Ensure we're in the right directory for cleanup
    if ($project_root && -d $project_root) {
        chdir $project_root;
    }
    
    if (-f 'build/tofu/terraform.tfstate') {
        note "Cleaning up test infrastructure...";
        
        # Try OpenTofu destroy first (proper way)
        if (-d 'build/tofu') {
            chdir 'build/tofu';
            my $destroy_result = system('tofu destroy -auto-approve >/dev/null 2>&1');
            chdir '../..';
            
            # If OpenTofu destroy failed, manually clean up libvirt resources
            if ($destroy_result != 0) {
                note "OpenTofu destroy failed, manually cleaning up libvirt resources...";
                
                # Clean up domain
                system('sudo virsh destroy torrust-tracker >/dev/null 2>&1');
                system('sudo virsh undefine torrust-tracker >/dev/null 2>&1');
                
                # Clean up volumes
                for my $vol_name (qw(torrust-cloudinit.iso torrust-tracker-vm.qcow2 ubuntu-22.04-base.qcow2)) {
                    system("sudo virsh vol-delete '$vol_name' --pool default >/dev/null 2>&1");
                }
            }
        }
        
        # Clean up build directory if everything was destroyed successfully
        if (system('sudo virsh domstate torrust-tracker >/dev/null 2>&1') != 0) {
            # Domain doesn't exist, safe to remove build state
            system('rm -rf build/tofu') if -d 'build/tofu';
        }
    }
    
    # Restore original working directory
    chdir $original_cwd if $original_cwd;
}

done_testing();
