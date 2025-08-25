use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use TorrustDeploy::App;

subtest 'App module loads correctly' => sub {
    ok(TorrustDeploy::App->can('run'), 'App has run method');
    ok(TorrustDeploy::App->isa('App::Cmd'), 'App inherits from App::Cmd');
};

subtest 'App has expected command names' => sub {
    my $app = TorrustDeploy::App->new;
    my @commands = sort $app->command_names;
    
    ok(grep(/^help$/, @commands), 'help command is available');
};

done_testing;
