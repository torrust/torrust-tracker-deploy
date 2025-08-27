package TorrustDeploy::SSH::CommandResult;

use v5.38;
use Moo;
use namespace::clean;

has 'output' => (
    is => 'ro',
    required => 1,
);

has 'exit_code' => (
    is => 'ro',
    required => 1,
);

has 'success' => (
    is => 'lazy',
);

sub _build_success {
    my ($self) = @_;
    return $self->exit_code == 0;
}

# Factory methods for common scenarios
sub success_result {
    my ($class, $output, $exit_code) = @_;
    $exit_code //= 0;
    
    return $class->new(
        output => $output,
        exit_code => $exit_code,
    );
}

sub failure_result {
    my ($class, $error_message, $exit_code) = @_;
    $exit_code //= 255;
    
    return $class->new(
        output => $error_message,
        exit_code => $exit_code,
    );
}

# Convenience methods
sub is_success {
    my ($self) = @_;
    return $self->success;
}

sub is_failure {
    my ($self) = @_;
    return !$self->success;
}

sub has_output {
    my ($self) = @_;
    return defined $self->output && length($self->output) > 0;
}

1;

__END__

=head1 NAME

TorrustDeploy::SSH::CommandResult - Value object for SSH command execution results

=head1 DESCRIPTION

Encapsulates the result of an SSH command execution, providing a consistent
interface and eliminating duplication of result handling logic.

=head1 SYNOPSIS

    use TorrustDeploy::SSH::CommandResult;
    
    # Create successful result
    my $result = TorrustDeploy::SSH::CommandResult->success_result(
        "Command output", 0
    );
    
    # Create failure result
    my $error = TorrustDeploy::SSH::CommandResult->failure_result(
        "Command failed", 1
    );
    
    # Check result
    if ($result->is_success) {
        say "Success: " . $result->output;
    } else {
        say "Failed with exit code: " . $result->exit_code;
    }

=head1 ATTRIBUTES

=head2 output

Required. The output from the command execution.

=head2 exit_code

Required. The exit code from the command execution.

=head2 success

Computed. Returns true if exit_code is 0, false otherwise.

=head1 METHODS

=head2 success_result($output, $exit_code)

Class method. Creates a successful command result.
If exit_code is not provided, defaults to 0.

=head2 failure_result($error_message, $exit_code)

Class method. Creates a failed command result.
If exit_code is not provided, defaults to 255.

=head2 is_success()

Returns true if the command was successful (exit_code == 0).

=head2 is_failure()

Returns true if the command failed (exit_code != 0).

=head2 has_output()

Returns true if the output is defined and non-empty.

=head1 DESIGN DECISIONS

=over 4

=item * B<success is computed>: The success attribute is derived from exit_code
to ensure consistency and avoid invalid states.

=item * B<Factory methods>: Provide convenient constructors for common scenarios
while maintaining the flexibility of the full constructor.

=item * B<Immutable>: All attributes are read-only to prevent accidental
modification and ensure value object semantics.

=back

=cut
