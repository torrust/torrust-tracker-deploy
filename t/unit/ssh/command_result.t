#!/usr/bin/env perl

use v5.38;
use Test2::V0;

use lib 'lib';
use TorrustDeploy::SSH::CommandResult;

subtest 'Constructor and Attributes' => sub {
    subtest 'Required attributes' => sub {
        my $result1 = dies { 
            TorrustDeploy::SSH::CommandResult->new() 
        };
        ok $result1, 'dies without required attributes';
        like $result1, qr/required/, 'error message mentions required attribute';
        
        my $result2 = dies { 
            TorrustDeploy::SSH::CommandResult->new(output => 'test') 
        };
        ok $result2, 'dies without exit_code';
        
        my $result3 = dies { 
            TorrustDeploy::SSH::CommandResult->new(exit_code => 0) 
        };
        ok $result3, 'dies without output';
    };
    
    subtest 'Valid construction' => sub {
        my $result = TorrustDeploy::SSH::CommandResult->new(
            output => 'test output',
            exit_code => 0,
        );
        
        is $result->output, 'test output', 'output is set correctly';
        is $result->exit_code, 0, 'exit_code is set correctly';
        ok $result->success, 'success is computed correctly for exit_code 0';
    };
    
    subtest 'Success computation' => sub {
        my $success_result = TorrustDeploy::SSH::CommandResult->new(
            output => 'success',
            exit_code => 0,
        );
        ok $success_result->success, 'exit_code 0 means success';
        
        my $failure_result = TorrustDeploy::SSH::CommandResult->new(
            output => 'error',
            exit_code => 1,
        );
        ok !$failure_result->success, 'exit_code 1 means failure';
        
        my $other_failure = TorrustDeploy::SSH::CommandResult->new(
            output => 'error',
            exit_code => 255,
        );
        ok !$other_failure->success, 'exit_code 255 means failure';
    };
};

subtest 'Factory Methods' => sub {
    subtest 'success_result factory' => sub {
        my $result = TorrustDeploy::SSH::CommandResult->success_result('output');
        
        is $result->output, 'output', 'output is set from factory';
        is $result->exit_code, 0, 'exit_code defaults to 0';
        ok $result->success, 'result is successful';
        
        # With custom exit code
        my $custom_result = TorrustDeploy::SSH::CommandResult->success_result('output', 0);
        is $custom_result->exit_code, 0, 'custom exit_code can be provided';
    };
    
    subtest 'failure_result factory' => sub {
        my $result = TorrustDeploy::SSH::CommandResult->failure_result('error message');
        
        is $result->output, 'error message', 'output is set from factory';
        is $result->exit_code, 255, 'exit_code defaults to 255';
        ok !$result->success, 'result is failure';
        
        # With custom exit code
        my $custom_result = TorrustDeploy::SSH::CommandResult->failure_result('error', 1);
        is $custom_result->exit_code, 1, 'custom exit_code can be provided';
    };
};

subtest 'Convenience Methods' => sub {
    my $success_result = TorrustDeploy::SSH::CommandResult->success_result('output');
    my $failure_result = TorrustDeploy::SSH::CommandResult->failure_result('error');
    
    subtest 'is_success method' => sub {
        ok $success_result->is_success, 'is_success returns true for successful result';
        ok !$failure_result->is_success, 'is_success returns false for failed result';
    };
    
    subtest 'is_failure method' => sub {
        ok !$success_result->is_failure, 'is_failure returns false for successful result';
        ok $failure_result->is_failure, 'is_failure returns true for failed result';
    };
    
    subtest 'has_output method' => sub {
        ok $success_result->has_output, 'has_output returns true for non-empty output';
        ok $failure_result->has_output, 'has_output returns true for error message';
        
        my $empty_result = TorrustDeploy::SSH::CommandResult->new(
            output => '',
            exit_code => 0,
        );
        ok !$empty_result->has_output, 'has_output returns false for empty string';
        
        my $undef_result = TorrustDeploy::SSH::CommandResult->new(
            output => undef,
            exit_code => 0,
        );
        ok !$undef_result->has_output, 'has_output returns false for undef';
    };
};

subtest 'Immutability' => sub {
    my $result = TorrustDeploy::SSH::CommandResult->new(
        output => 'original',
        exit_code => 0,
    );
    
    # These should all fail since attributes are read-only
    my $error1 = dies { $result->output('modified') };
    ok $error1, 'output attribute is read-only';
    
    my $error2 = dies { $result->exit_code(1) };
    ok $error2, 'exit_code attribute is read-only';
    
    my $error3 = dies { $result->success(0) };
    ok $error3, 'success attribute is read-only';
    
    # Verify values haven't changed
    is $result->output, 'original', 'output remains unchanged';
    is $result->exit_code, 0, 'exit_code remains unchanged';
    ok $result->success, 'success remains unchanged';
};

done_testing();
