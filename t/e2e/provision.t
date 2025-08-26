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

plan tests => 4;

# Change to project root for the test
my $original_cwd = path('.');
my $project_root = path(__FILE__)->parent->parent->parent;
chdir $project_root or die "Cannot change to project root: $!";

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
    if (-f 'build/tofu/terraform.tfstate') {
        note "Cleaning up test infrastructure...";
        # Manual cleanup using OpenTofu since destroy command doesn't exist yet
        if (-d 'build/tofu') {
            chdir 'build/tofu';
            system('tofu', 'destroy', '-auto-approve') if -f 'main.tf';
            chdir '../..';
        }
    }
    
    # Restore original working directory
    chdir $original_cwd if $original_cwd;
}

done_testing();
