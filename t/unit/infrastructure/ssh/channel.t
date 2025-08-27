#!/usr/bin/env perl

use v5.38;
use Test2::V0;

use lib 'lib';
use TorrustDeploy::Infrastructure::SSH::Channel;

# Mock channel object for testing (simple hash-based mock)
package MockChannel {
    use v5.38;
    
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }
    
    sub exec { return $_[0]->{exec_result} // 1; }
    sub error { return $_[0]->{error_msg} // 'Mock error'; }
    sub blocking { return 1; }
    sub eof { return $_[0]->{eof_result} // 1; }
    sub read { 
        my ($self, $buffer_ref, $size) = @_;
        if ($self->{read_output}) {
            $_[1] = $self->{read_output};  # Set buffer via reference
            my $length = length($_[1]);
            # Only clear after first read to simulate timeout behavior
            $self->{read_calls} //= 0;
            $self->{read_calls}++;
            if ($self->{read_calls} > 1) {
                $self->{read_output} = '';  # Clear to prevent infinite loops
            }
            return $length;
        }
        $_[1] = '';  # Always set buffer to empty string when no data
        return 0;
    }
    sub wait_closed { return 1; }
    sub exit_status { return $_[0]->{exit_status} // 0; }
    sub close { return 1; }
}

subtest 'Constructor and Attributes' => sub {
    subtest 'Required attributes' => sub {
        my $result = dies { 
            TorrustDeploy::Infrastructure::SSH::Channel->new() 
        };
        ok $result, 'dies without required channel';
        
        like $result, qr/required/, 'error message mentions required attribute';
    };
    
    subtest 'Default values' => sub {
        my $mock_channel = MockChannel->new();
        my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
            channel => $mock_channel
        );
        
        is $channel->channel, $mock_channel, 'channel is set correctly';
        is $channel->timeout, 30, 'default timeout is 30 seconds';
    };
    
    subtest 'Custom values' => sub {
        my $mock_channel = MockChannel->new();
        my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
            channel => $mock_channel,
            timeout => 60,
        );
        
        is $channel->channel, $mock_channel, 'custom channel';
        is $channel->timeout, 60, 'custom timeout';
    };
    
    subtest 'Read-only attributes' => sub {
        my $mock_channel = MockChannel->new();
        my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
            channel => $mock_channel
        );
        
        my $result1 = dies { $channel->channel('new_channel') };
        ok $result1, 'channel is read-only';
        
        my $result2 = dies { $channel->timeout(90) };
        ok $result2, 'timeout is read-only';
    };
};

subtest 'Method existence' => sub {
    my $mock_channel = MockChannel->new();
    my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
        channel => $mock_channel
    );
    
    can_ok $channel, 'execute_command';
    can_ok $channel, 'health_check';
    can_ok $channel, 'read_output';
    can_ok $channel, 'get_exit_code';
    can_ok $channel, 'close';
};

subtest 'Command execution structure' => sub {
    my $mock_channel = MockChannel->new(exec_result => 0); # Simulate exec failure
    
    my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
        channel => $mock_channel
    );
    
    # Test command execution with failed exec
    my $result = dies { 
        $channel->execute_command('test command')
    };
    ok $result, 'execute_command dies when channel exec fails';
    
    like $result, qr/Failed to execute command/, 'error message mentions command execution failure';
};

subtest 'Successful command execution' => sub {
    my $mock_channel = MockChannel->new(
        exec_result => 1,
        read_output => '',
        exit_status => 0,
    );
    
    my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
        channel => $mock_channel
    );
    
    my $result = $channel->execute_command('echo test');
    
    # Should return a structured response
    is ref($result), 'HASH', 'execute_command returns hashref';
    ok exists $result->{output}, 'result has output key';
    ok exists $result->{success}, 'result has success key';
    ok exists $result->{exit_code}, 'result has exit_code key';
    
    # Should indicate success
    ok $result->{success}, 'successful command shows success = true';
    is $result->{exit_code}, 0, 'successful command shows exit_code = 0';
};

subtest 'Failed command execution' => sub {
    my $mock_channel = MockChannel->new(
        exec_result => 1,
        read_output => '',
        exit_status => 1, # Non-zero exit
    );
    
    my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
        channel => $mock_channel
    );
    
    my $result = $channel->execute_command('exit 1');
    
    # Should indicate failure
    ok !$result->{success}, 'failed command shows success = false';
    is $result->{exit_code}, 1, 'failed command shows correct exit_code';
};

subtest 'Health check' => sub {
    subtest 'Successful health check' => sub {
        my $mock_channel = MockChannel->new(
            exec_result => 1,
            read_output => 'health_check',
        );
        
        my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
            channel => $mock_channel
        );
        
        my $result = $channel->health_check();
        ok $result, 'health check returns true for successful check';
    };
    
    subtest 'Failed health check - exec fails' => sub {
        my $mock_channel = MockChannel->new(exec_result => 0); # Exec fails
        
        my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
            channel => $mock_channel
        );
        
        my $result = $channel->health_check();
        ok !$result, 'health check returns false when exec fails';
    };
};

subtest 'Close method' => sub {
    my $mock_channel = MockChannel->new();
    
    my $channel = TorrustDeploy::Infrastructure::SSH::Channel->new(
        channel => $mock_channel
    );
    
    my $result = dies { $channel->close() };
    ok !$result, 'close method can be called without dying';
};

done_testing();
