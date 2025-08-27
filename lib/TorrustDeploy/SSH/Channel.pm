package TorrustDeploy::SSH::Channel;

use v5.38;
use Moo;
use TorrustDeploy::SSH::CommandResult;
use Carp qw(croak);
use namespace::clean;

has 'channel' => (
    is => 'ro',
    required => 1,
);

has 'timeout' => (
    is => 'ro',
    default => sub { 30 },
);

sub execute_command {
    my ($self, $command) = @_;
    
    unless ($self->channel->exec($command)) {
        my $error = $self->channel->error || 'Unknown error';
        croak "Failed to execute command '$command': $error";
    }
    
    my $output = $self->read_output();
    my $exit_code = $self->get_exit_code();
    
    return TorrustDeploy::SSH::CommandResult->new(
        output => $output,
        exit_code => $exit_code,
    );
}

sub health_check {
    my ($self) = @_;
    
    # Use a simple echo command as health check
    my $test_command = 'echo "health_check"';
    return 0 unless $self->channel->exec($test_command);
    
    my $output = $self->_read_health_check_output();
    $self->close();
    
    return $output =~ /health_check/;
}

sub read_output {
    my ($self) = @_;
    
    $self->_setup_non_blocking_read();
    my $output = $self->_read_with_timeout();
    $output .= $self->_read_remaining_data();
    
    return $output;
}

sub get_exit_code {
    my ($self) = @_;
    
    $self->channel->wait_closed();
    my $exit_code = $self->channel->exit_status();
    return defined $exit_code ? $exit_code : 0;
}

sub close {
    my ($self) = @_;
    
    $self->channel->close();
}

#==============================================================================
# PRIVATE METHODS - Channel I/O Operations
#==============================================================================

sub _setup_non_blocking_read {
    my ($self) = @_;
    
    $self->channel->blocking(0);
}

sub _read_with_timeout {
    my ($self) = @_;
    
    my $output = '';
    my $start_time = time();
    
    while (time() - $start_time < $self->timeout) {
        my $buffer = $self->_try_read_chunk();
        
        if (defined $buffer && length($buffer) > 0) {
            $output .= $buffer;
            next;
        }
        
        last if $self->channel->eof();
        $self->_small_delay_to_prevent_busy_waiting();
    }
    
    return $output;
}

sub _try_read_chunk {
    my ($self) = @_;
    
    my $buffer;
    my $bytes_read = $self->channel->read($buffer, 4096);
    
    return (defined $bytes_read && $bytes_read > 0) ? $buffer : undef;
}

sub _small_delay_to_prevent_busy_waiting {
    my ($self) = @_;
    
    select(undef, undef, undef, 0.1);
}

sub _read_remaining_data {
    my ($self) = @_;
    
    my $remaining_output = '';
    
    # Final blocking read to get any remaining data
    $self->channel->blocking(1);
    while (my $bytes_read = $self->channel->read(my $buffer, 4096)) {
        last unless defined $bytes_read && $bytes_read > 0;
        $remaining_output .= $buffer;
    }
    
    return $remaining_output;
}

sub _read_health_check_output {
    my ($self) = @_;
    
    my $output = '';
    my $timeout = time() + 5;  # 5 second timeout for health check
    
    while (time() < $timeout) {
        my $buffer;
        my $bytes = $self->channel->read($buffer, 1024);
        last if $bytes <= 0;
        $output .= $buffer;
        last if $output =~ /health_check/;
    }
    
    return $output;
}

1;

__END__

=head1 NAME

TorrustDeploy::SSH::Channel - SSH channel wrapper for command execution

=head1 DESCRIPTION

Wraps a Net::SSH2::Channel instance to provide a clean interface for command
execution with timeout support and proper I/O handling. Encapsulates complex
channel operations in a testable, reusable component.

=head1 SYNOPSIS

    use TorrustDeploy::SSH::Channel;
    
    # Create channel from SSH2 connection
    my $raw_channel = $ssh2->channel();
    my $channel = TorrustDeploy::SSH::Channel->new(
        channel => $raw_channel,
        timeout => 30,
    );
    
    # Execute command
    my $result = $channel->execute_command('echo "Hello World"');
    # $result = { 
    #     output => "Hello World\n", 
    #     success => 1, 
    #     exit_code => 0 
    # }
    
    # Health check
    my $is_healthy = $channel->health_check();

=head1 ATTRIBUTES

=head2 channel

Required. The Net::SSH2::Channel instance to wrap.

=head2 timeout

Command execution timeout in seconds. Defaults to 30.

=head1 METHODS

=head2 execute_command($command)

Executes a command on the channel and returns a result hashref with:
- output: Command output string
- success: Boolean indicating if command succeeded (exit code 0)
- exit_code: Command exit code

=head2 health_check()

Performs a lightweight health check by executing an echo command.
Returns true if the channel is working, false otherwise.

=head2 read_output()

Reads all output from the channel with timeout protection.
Returns the complete output as a string.

=head2 get_exit_code()

Waits for the channel to close and returns the command exit code.

=head2 close()

Closes the SSH channel.

=cut
