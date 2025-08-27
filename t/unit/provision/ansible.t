use v5.38;
use Test::More tests => 4;
use File::Temp qw(tempdir);
use Path::Tiny qw(path);

# Test the Ansible wrapper module
use_ok('TorrustDeploy::Provision::Ansible');

subtest 'constructor' => sub {
    plan tests => 2;
    
    my $ansible = TorrustDeploy::Provision::Ansible->new();
    ok(defined $ansible, 'constructor returns defined object');
    isa_ok($ansible, 'TorrustDeploy::Provision::Ansible', 'object has correct class');
};

subtest 'methods exist' => sub {
    plan tests => 2;
    
    my $ansible = TorrustDeploy::Provision::Ansible->new();
    can_ok($ansible, 'copy_templates_and_generate_inventory');
    can_ok($ansible, 'run_verification');
};

subtest 'basic functionality test' => sub {
    plan tests => 1;
    
    # This is a simple smoke test - just verify the module loads and can be instantiated
    my $ansible = TorrustDeploy::Provision::Ansible->new();
    ok(ref($ansible) eq 'TorrustDeploy::Provision::Ansible', 'module works correctly');
};

done_testing();
