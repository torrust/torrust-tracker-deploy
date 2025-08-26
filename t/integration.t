use Test2::V0;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use TorrustDeploy::App;

subtest 'App runs help command explicitly' => sub {
    local @ARGV = ('help');
    
    my $output = '';
    {
        local *STDOUT;
        open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";
        
        eval {
            TorrustDeploy::App->run;
        };
        
        close STDOUT;
    }
    
    ok(!$@, 'App runs help command without dying') or diag("Error: $@");
    like($output, qr/Available commands/, 'Help command produces expected output');
    like($output, qr/provision:\s*Provision Torrust Tracker VM/, 'Help shows provision command with description');
};

done_testing;
