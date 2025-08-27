use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../../lib";
use Path::Tiny qw(path);
use File::Temp qw(tempdir);

use TorrustDeploy::OpenTofu;

subtest 'OpenTofu module loads correctly' => sub {
    ok(TorrustDeploy::OpenTofu->can('new'), 'OpenTofu has new method');
    ok(TorrustDeploy::OpenTofu->can('copy_templates'), 'OpenTofu has copy_templates method');
    ok(TorrustDeploy::OpenTofu->can('init'), 'OpenTofu has init method');
    ok(TorrustDeploy::OpenTofu->can('apply'), 'OpenTofu has apply method');
    ok(TorrustDeploy::OpenTofu->can('get_vm_ip'), 'OpenTofu has get_vm_ip method');
};

subtest 'OpenTofu instance creation' => sub {
    my $tofu = TorrustDeploy::OpenTofu->new();
    ok($tofu, 'OpenTofu instance created successfully');
    isa_ok($tofu, 'TorrustDeploy::OpenTofu');
};

subtest 'OpenTofu template copying functionality' => sub {
    my $tofu = TorrustDeploy::OpenTofu->new();
    
    # Create temporary directory for testing
    my $temp_dir = tempdir(CLEANUP => 1);
    my $test_tofu_dir = path($temp_dir)->child('test-tofu');
    $test_tofu_dir->mkpath;
    
    # Verify templates directory exists before testing
    my $templates_dir = path('templates/provision');
    skip_all "Templates directory not found: $templates_dir" unless $templates_dir->exists;
    
    # Test the copy_templates method
    eval {
        $tofu->copy_templates($test_tofu_dir);
    };
    ok(!$@, 'copy_templates method executes without error') or diag("Error: $@");
    
    # Verify files were copied correctly
    my $target_main_tf = $test_tofu_dir->child('main.tf');
    my $target_cloud_init = $test_tofu_dir->child('cloud-init.yml');
    
    ok($target_main_tf->exists, 'main.tf copied to target directory');
    ok($target_cloud_init->exists, 'cloud-init.yml copied to target directory');
    
    # Verify content matches the templates if templates exist
    my $main_tf_template = $templates_dir->child('tofu/providers/libvirt/main.tf');
    my $cloud_init_template = $templates_dir->child('cloud-init.yml');
    
    if ($main_tf_template->exists && $cloud_init_template->exists) {
        is($target_main_tf->slurp_utf8, $main_tf_template->slurp_utf8, 'main.tf content matches template');
        is($target_cloud_init->slurp_utf8, $cloud_init_template->slurp_utf8, 'cloud-init.yml content matches template');
    }
};

done_testing;
