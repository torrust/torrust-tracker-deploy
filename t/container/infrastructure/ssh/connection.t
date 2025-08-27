#!/usr/bin/env perl

use v5.38;
use Test2::V0;
use File::Spec;
use Cwd qw(getcwd);

use lib 'lib';
use TorrustDeploy::Infrastructure::SSH::Connection;

# Configuration for test SSH server
my $SSH_HOST = 'localhost';
my $SSH_PORT = 2222;
my $SSH_USER = 'testuser';
my $SSH_PASS = 'testpass123';
my $TEST_KEY_PATH = File::Spec->catfile(getcwd(), 't', 'container', 'fixtures', 'test_key');

# Skip tests if Docker is not available
sub docker_available {
    return system('docker --version >/dev/null 2>&1') == 0;
}

sub docker_compose_available {
    return system('docker compose version >/dev/null 2>&1') == 0;
}

plan skip_all => 'Docker not available' unless docker_available();
plan skip_all => 'Docker Compose not available' unless docker_compose_available();

# Test environment setup and teardown
sub start_ssh_server {
    my $fixtures_dir = File::Spec->catdir(getcwd(), 't', 'container', 'fixtures');
    
    # Stop any existing container
    system("cd '$fixtures_dir' && docker compose down >/dev/null 2>&1");
    
    # Start SSH server
    my $result = system("cd '$fixtures_dir' && docker compose up -d --build");
    if ($result != 0) {
        BAIL_OUT("Failed to start SSH test server");
    }
    
    # Wait for SSH server to be ready
    my $max_attempts = 30; # 30 seconds
    my $attempts = 0;
    
    while ($attempts < $max_attempts) {
        my $check = system("timeout 2 nc -z $SSH_HOST $SSH_PORT >/dev/null 2>&1");
        last if $check == 0;
        
        $attempts++;
        sleep(1);
    }
    
    if ($attempts >= $max_attempts) {
        BAIL_OUT("SSH test server failed to start within 30 seconds");
    }
    
    # Give SSH a moment to fully initialize
    sleep(2);
}

sub stop_ssh_server {
    my $fixtures_dir = File::Spec->catdir(getcwd(), 't', 'container', 'fixtures');
    system("cd '$fixtures_dir' && docker compose down >/dev/null 2>&1");
}

# Set up test environment
start_ssh_server();

# Ensure cleanup happens even if tests fail
END { stop_ssh_server(); }

subtest 'Container SSH Connection Tests' => sub {
    subtest 'Connection and Authentication' => sub {
        my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(
            host => "$SSH_HOST:$SSH_PORT",
            username => $SSH_USER,
            password => $SSH_PASS,
            ssh_key_path => $TEST_KEY_PATH,
            connect_timeout => 10,
            command_timeout => 15,
        );
        
        # Test password authentication
        ok $ssh->test_password_connection(), 'password authentication works with real SSH server';
        is $ssh->_authenticated, 1, 'authentication state is set to true';
        
        # Test key authentication (should also work)
        $ssh->disconnect(); # Reset connection
        ok $ssh->test_key_connection(), 'key authentication works with real SSH server';
        is $ssh->_authenticated, 1, 'key authentication sets state to true';
    };
    
    subtest 'Command Execution' => sub {
        my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(
            host => "$SSH_HOST:$SSH_PORT",
            username => $SSH_USER,
            password => $SSH_PASS,
            connect_timeout => 10,
            command_timeout => 15,
        );
        
        # Test simple command
        my $result = $ssh->execute_command('echo "Hello E2E Test"');
        ok $result->is_success, 'simple echo command succeeds';
        is $result->exit_code, 0, 'echo command has exit code 0';
        like $result->output, qr/Hello E2E Test/, 'echo command output is correct';
        
        # Test command with variables
        my $whoami_result = $ssh->execute_command('whoami');
        ok $whoami_result->is_success, 'whoami command succeeds';
        like $whoami_result->output, qr/testuser/, 'whoami returns correct username';
        
        # Test command that should fail
        my $fail_result = $ssh->execute_command('exit 42');
        ok $fail_result->is_failure, 'failing command returns failure=true';
        is $fail_result->exit_code, 42, 'failing command returns correct exit code';
        
        # Test sudo command
        my $sudo_result = $ssh->execute_command_with_sudo('whoami');
        ok $sudo_result->is_success, 'sudo command succeeds';
        like $sudo_result->output, qr/root/, 'sudo command runs as root';
    };
    
    subtest 'Connection Reuse' => sub {
        my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(
            host => "$SSH_HOST:$SSH_PORT",
            username => $SSH_USER,
            password => $SSH_PASS,
            connect_timeout => 10,
            command_timeout => 15,
        );
        
        # Execute multiple commands to test connection reuse
        my $cmd1 = $ssh->execute_command('echo "Command 1"');
        my $cmd2 = $ssh->execute_command('echo "Command 2"');
        my $cmd3 = $ssh->execute_command('echo "Command 3"');
        
        ok $cmd1->is_success, 'first command succeeds';
        ok $cmd2->is_success, 'second command succeeds (connection reused)';
        ok $cmd3->is_success, 'third command succeeds (connection reused)';
        
        like $cmd1->output, qr/Command 1/, 'first command output correct';
        like $cmd2->output, qr/Command 2/, 'second command output correct';
        like $cmd3->output, qr/Command 3/, 'third command output correct';
    };
    
    subtest 'Authentication Fallback' => sub {
        # Test with wrong password but correct key
        my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(
            host => "$SSH_HOST:$SSH_PORT",
            username => $SSH_USER,
            password => 'wrong_password',
            ssh_key_path => $TEST_KEY_PATH,
            connect_timeout => 10,
            command_timeout => 15,
        );
        
        # Password auth should fail
        ok !$ssh->test_password_connection(), 'wrong password fails authentication';
        
        # But key auth should succeed
        ok $ssh->test_key_connection(), 'key authentication succeeds even after password failure';
        
        # Command execution should work with key auth
        my $result = $ssh->execute_command('echo "Fallback test"');
        ok $result->is_success, 'command works after authentication fallback';
    };
    
    subtest 'Error Handling' => sub {
        # Test with completely wrong host
        my $ssh_bad_host = TorrustDeploy::Infrastructure::SSH::Connection->new(
            host => 'nonexistent.example.com:22',
            username => $SSH_USER,
            password => $SSH_PASS,
            connect_timeout => 3,
            command_timeout => 5,
        );
        
        ok !$ssh_bad_host->test_password_connection(), 'connection to bad host fails gracefully';
        
        my $result = $ssh_bad_host->execute_command('echo test');
        ok $result->is_failure, 'command execution fails with bad host';
        is $result->exit_code, 255, 'bad host returns exit code 255';
        like $result->output, qr/Authentication failed/, 'error message indicates authentication failure';
    };
    
    subtest 'Disconnect and Cleanup' => sub {
        my $ssh = TorrustDeploy::Infrastructure::SSH::Connection->new(
            host => "$SSH_HOST:$SSH_PORT",
            username => $SSH_USER,
            password => $SSH_PASS,
        );
        
        # Establish connection
        ok $ssh->test_password_connection(), 'connection established';
        is $ssh->_authenticated, 1, 'authenticated state is true';
        
        # Disconnect
        ok lives { $ssh->disconnect() }, 'disconnect method works without errors';
        is $ssh->_authenticated, 0, 'authenticated state reset after disconnect';
        
        # Should be able to reconnect
        ok $ssh->test_password_connection(), 'can reconnect after disconnect';
    };
};

# Clean up
stop_ssh_server();

done_testing();
