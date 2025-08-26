use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../../lib";

use TorrustDeploy::Provision::OpenTofu;

subtest 'OpenTofu module loads correctly' => sub {
    ok(TorrustDeploy::Provision::OpenTofu->can('new'), 'OpenTofu has new method');
    ok(TorrustDeploy::Provision::OpenTofu->can('init'), 'OpenTofu has init method');
    ok(TorrustDeploy::Provision::OpenTofu->can('apply'), 'OpenTofu has apply method');
    ok(TorrustDeploy::Provision::OpenTofu->can('get_vm_ip'), 'OpenTofu has get_vm_ip method');
};

subtest 'OpenTofu instance creation' => sub {
    my $tofu = TorrustDeploy::Provision::OpenTofu->new();
    ok($tofu, 'OpenTofu instance created successfully');
    isa_ok($tofu, 'TorrustDeploy::Provision::OpenTofu');
};

done_testing;
