use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Path::Tiny qw(path);
use File::Temp qw(tempdir);

use TorrustDeploy::App::Command::provision;
use TorrustDeploy::App;

subtest 'Provision command module loads correctly' => sub {
    ok(TorrustDeploy::App::Command::provision->can('execute'), 'Provision command has execute method');
    ok(TorrustDeploy::App::Command::provision->can('abstract'), 'Provision command has abstract method');
    ok(TorrustDeploy::App::Command::provision->can('description'), 'Provision command has description method');
};

subtest 'Provision command provides correct metadata' => sub {
    is(TorrustDeploy::App::Command::provision->abstract, 'Provision Torrust Tracker VM using OpenTofu', 'Correct abstract');
    
    my $description = TorrustDeploy::App::Command::provision->description;
    like($description, qr/Provision a Torrust Tracker virtual machine/, 'Description mentions VM provisioning');
    like($description, qr/OpenTofu/, 'Description mentions OpenTofu');
    like($description, qr/libvirt/, 'Description mentions libvirt');
};

subtest 'Provision command is discoverable by app' => sub {
    my $app = TorrustDeploy::App->new;
    my @commands = sort $app->command_names;
    
    ok(grep(/^provision$/, @commands), 'provision command is available in app');
};

subtest 'Template files exist and are readable' => sub {
    my $project_root = path($Bin)->parent;
    my $templates_dir = $project_root->child('templates/provision');
    
    ok($templates_dir->exists, 'Templates/provision directory exists');
    ok($templates_dir->is_dir, 'Templates/provision directory is a directory');
    
    my $main_tf_template = $templates_dir->child('tofu/providers/libvirt/main.tf');
    my $cloud_init_template = $templates_dir->child('cloud-init.yml');
    
    ok($main_tf_template->exists, 'main.tf template exists');
    ok($main_tf_template->is_file, 'main.tf template is a file');
    ok(-r $main_tf_template, 'main.tf template is readable');
    
    ok($cloud_init_template->exists, 'cloud-init.yml template exists');
    ok($cloud_init_template->is_file, 'cloud-init.yml template is a file');
    ok(-r $cloud_init_template, 'cloud-init.yml template is readable');
};

subtest 'Template files have expected content' => sub {
    my $project_root = path($Bin)->parent;
    my $templates_dir = $project_root->child('templates/provision');
    
    my $main_tf_content = $templates_dir->child('tofu/providers/libvirt/main.tf')->slurp_utf8;
    like($main_tf_content, qr/required_providers/, 'main.tf contains provider configuration');
    like($main_tf_content, qr/libvirt/, 'main.tf contains libvirt provider');
    like($main_tf_content, qr/libvirt_domain/, 'main.tf contains domain resource');
    like($main_tf_content, qr/torrust-tracker/, 'main.tf contains torrust-tracker VM name');
    
    my $cloud_init_content = $templates_dir->child('cloud-init.yml')->slurp_utf8;
    like($cloud_init_content, qr/#cloud-config/, 'cloud-init.yml has cloud-config header');
    like($cloud_init_content, qr/hostname:\s*torrust-tracker/, 'cloud-init.yml sets hostname');
    like($cloud_init_content, qr/name:\s*torrust/, 'cloud-init.yml creates torrust user');
};

subtest 'Provision command template copying functionality' => sub {
    # Create a temporary directory for testing
    my $temp_dir = tempdir(CLEANUP => 1);
    my $test_tofu_dir = path($temp_dir)->child('test-tofu');
    
    # Create a mock provision command instance
    my $app = TorrustDeploy::App->new;
    my $provision_cmd = TorrustDeploy::App::Command::provision->new({
        app => $app,
    });
    
    # Test the _copy_templates method directly
    my $project_root = path($Bin)->parent;
    my $templates_dir = $project_root->child('templates/provision');
    
    # Test that template directory exists
    ok($templates_dir->exists, 'Source templates/provision directory exists');
    
    # Create the target directory
    $test_tofu_dir->mkpath;
    ok($test_tofu_dir->exists, 'Test tofu directory created');
    
    # Test the actual _copy_templates method with both required parameters
    eval {
        $provision_cmd->_copy_templates($templates_dir, $test_tofu_dir);
    };
    ok(!$@, 'Template copying method executes without error') or diag("Error: $@");
    
    # Verify files were copied correctly
    my $target_main_tf = $test_tofu_dir->child('main.tf');
    my $target_cloud_init = $test_tofu_dir->child('cloud-init.yml');
    
    ok($target_main_tf->exists, 'main.tf copied to target directory');
    ok($target_cloud_init->exists, 'cloud-init.yml copied to target directory');
    
    # Verify content matches the templates
    my $main_tf_template = $templates_dir->child('tofu/providers/libvirt/main.tf');
    my $cloud_init_template = $templates_dir->child('cloud-init.yml');
    
    is($target_main_tf->slurp_utf8, $main_tf_template->slurp_utf8, 'main.tf content matches template');
    is($target_cloud_init->slurp_utf8, $cloud_init_template->slurp_utf8, 'cloud-init.yml content matches template');
};

subtest 'Provision command internal methods' => sub {
    my $app = TorrustDeploy::App->new;
    my $provision_cmd = TorrustDeploy::App::Command::provision->new({
        app => $app,
    });
    
    # Test that the command has the expected private methods
    ok($provision_cmd->can('_copy_templates'), 'Provision command has _copy_templates method');
    ok($provision_cmd->can('_run_tofu_init'), 'Provision command has _run_tofu_init method');
    ok($provision_cmd->can('_run_tofu_apply'), 'Provision command has _run_tofu_apply method');
};

done_testing;
