#!/usr/bin/env perl

use v5.40;
use Test2::V0;
use Test::Exception;

use lib 'lib';
use TorrustDeploy::Infrastructure::SSH::Connection;

subtest 'Constructor and Attributes' => sub {
    subtest 'Required attributes' => sub {
        dies_ok { 
            TorrustDeploy::Infrastructure::SSH::Connection->new() 
        } 'dies without required host';
        
        like $@, qr/required/, 'error message mentions required attribute';
    };
    
    subtest 'Default values' => sub {
        my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(host => '192.168.1.100');
        
        is $ssh->host, '192.168.1.100', 'host is set correctly';
        is $ssh->username, 'torrust', 'default username';
        is $ssh->password, 'torrust123', 'default password';
        like $ssh->ssh_key_path, qr/testing_rsa$/, 'default ssh key path';
        is $ssh->connect_timeout, 10, 'default connect timeout';
        is $ssh->command_timeout, 30, 'default command timeout (updated to 30)';
    };
    
    subtest 'Custom values' => sub {
        my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(
            host => '10.0.0.5',
            username => 'custom_user',
            password => 'secure_password',
            ssh_key_path => '/custom/path/id_rsa',
            connect_timeout => 30,
            command_timeout => 60,
        );
        
        is $ssh->host, '10.0.0.5', 'custom host';
        is $ssh->username, 'custom_user', 'custom username';
        is $ssh->password, 'secure_password', 'custom password';
        is $ssh->ssh_key_path, '/custom/path/id_rsa', 'custom ssh key path';
        is $ssh->connect_timeout, 30, 'custom connect timeout';
        is $ssh->command_timeout, 60, 'custom command timeout';
    };
    
    subtest 'Read-only attributes' => sub {
        my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(host => '192.168.1.100');
        
        dies_ok { $ssh->host('new_host') } 'host is read-only';
        dies_ok { $ssh->username('new_user') } 'username is read-only';
        dies_ok { $ssh->password('new_pass') } 'password is read-only';
    };
};

subtest 'Method existence and basic behavior' => sub {
    my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(host => '192.168.1.100');
    
    # Test that methods exist and can be called
    can_ok $ssh, 'test_password_connection';
    can_ok $ssh, 'test_key_connection';
    can_ok $ssh, 'execute_command';
    can_ok $ssh, 'execute_command_with_sudo';
    can_ok $ssh, 'disconnect';
    
    # Test initial authentication state
    is $ssh->_authenticated, 0, 'initial authentication state is false';
};

subtest 'Connection failure handling' => sub {
    # Test with invalid host that should fail to connect
    my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(host => '999.999.999.999');
    
    # These should fail gracefully and return false (not die)
    lives_ok { 
        my $result = $ssh->test_password_connection();
        ok !$result, 'password connection to invalid host returns false';
    } 'password connection failure is handled gracefully';
    
    lives_ok { 
        my $result = $ssh->test_key_connection();
        ok !$result, 'key connection to invalid host returns false';
    } 'key connection failure is handled gracefully';
};

subtest 'Command execution structure' => sub {
    my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(host => '999.999.999.999');
    
    # Test command execution with failed connection
    my $result = $ssh->execute_command('echo test');
    
    # Should return a structured response even on failure
    is ref($result), 'HASH', 'execute_command returns hashref';
    ok exists $result->{output}, 'result has output key';
    ok exists $result->{success}, 'result has success key';
    ok exists $result->{exit_code}, 'result has exit_code key';
    
    # Should indicate failure
    ok !$result->{success}, 'failed connection shows success = false';
    is $result->{exit_code}, 255, 'failed connection shows exit_code = 255';
};

subtest 'Sudo command wrapper' => sub {
    my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(host => '999.999.999.999');
    
    # Test that sudo wrapper calls execute_command
    my $result = $ssh->execute_command_with_sudo('systemctl status');
    
    # Should return same structure as execute_command
    is ref($result), 'HASH', 'execute_command_with_sudo returns hashref';
    ok exists $result->{output}, 'sudo result has output key';
    ok exists $result->{success}, 'sudo result has success key';
    ok exists $result->{exit_code}, 'sudo result has exit_code key';
};

subtest 'Disconnect and cleanup' => sub {
    my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(host => '192.168.1.100');
    
    # Test disconnect method exists and can be called
    lives_ok { $ssh->disconnect() } 'disconnect method can be called';
    
    # Test that authentication state is reset
    is $ssh->_authenticated, 0, 'authentication state is reset after disconnect';
};

subtest 'Helper methods' => sub {
    my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(host => '192.168.1.100');
    
    # Test private helper methods exist
    can_ok $ssh, '_ensure_authenticated';
    can_ok $ssh, '_find_public_key_path';
    can_ok $ssh, '_read_channel_output';
    
    # Test public key path finding logic
    my $public_key_path = $ssh->_find_public_key_path();
    ok defined($public_key_path), 'public key path finder returns a value';
    like $public_key_path, qr/testing_rsa/, 'public key path includes key name';
};

done_testing();
