use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use TorrustDeploy::App::Command::help;
use TorrustDeploy::App;

subtest 'Help command module loads correctly' => sub {
    ok(TorrustDeploy::App::Command::help->can('execute'), 'Help command has execute method');
    ok(TorrustDeploy::App::Command::help->can('abstract'), 'Help command has abstract method');
    ok(TorrustDeploy::App::Command::help->can('description'), 'Help command has description method');
};

subtest 'Help command provides correct metadata' => sub {
    is(TorrustDeploy::App::Command::help->abstract, 'Show help information', 'Correct abstract');
    
    my $description = TorrustDeploy::App::Command::help->description;
    like($description, qr/Torrust Tracker deployment tool/, 'Description mentions the tool');
};

subtest 'Help command execution' => sub {
    my $app = TorrustDeploy::App->new;
    my $help_cmd = TorrustDeploy::App::Command::help->new({
        app => $app,
    });
    
    ok($help_cmd, 'Help command can be instantiated');
    
    # Test that execute method doesn't die
    my $output = '';
    {
        local *STDOUT;
        open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";
        eval { $help_cmd->execute({}, []) };
        close STDOUT;
    }
    
    ok(!$@, 'Help command execute does not die') or diag("Error: $@");
    like($output, qr/Torrust Tracker deployment tool/, 'Help output contains expected text');
};

done_testing;
