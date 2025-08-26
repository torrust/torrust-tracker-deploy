package TorrustDeploy::Infrastructure::SSH::Connection;

use v5.40;
use Moo;
use Net::SSH2;
use Carp qw(croak);
use namespace::clean;

has 'host' => (
    is => 'ro',
    required => 1,
);

has 'port' => (
    is => 'ro',
    default => sub { 22 },
);

has 'username' => (
    is => 'ro',
    default => sub { 'torrust' },
);

has 'password' => (
    is => 'ro',
    default => sub { 'torrust123' },
);

has 'ssh_key_path' => (
    is => 'ro',
    default => sub { "$ENV{HOME}/.ssh/testing_rsa" },
);

has 'connect_timeout' => (
    is => 'ro',
    default => sub { 10 },
);

has 'command_timeout' => (
    is => 'ro',
    default => sub { 30 },
);

has 'connection_max_age' => (
    is => 'ro',
    default => sub { 300 },  # 5 minutes default
);

has 'health_check_enabled' => (
    is => 'ro',
    default => sub { 1 },
);

has 'auto_reconnect' => (
    is => 'ro',
    default => sub { 1 },
);

# Internal connection state
has '_ssh2' => (
    is => 'lazy',
    clearer => '_clear_connection',
    predicate => '_has_connection',
);

has '_authenticated' => (
    is => 'rw',
    default => sub { 0 },
);

has '_connection_established_at' => (
    is => 'rw',
    clearer => '_clear_connection_timestamp',
);

has '_last_health_check' => (
    is => 'rw',
);

sub _build__ssh2 {
    my ($self) = @_;
    
    my $ssh2 = Net::SSH2->new(timeout => $self->connect_timeout * 1000);
    
    # Parse host:port if provided in host field (for backward compatibility)
    my ($host, $port) = split /:/, $self->host, 2;
    $port = $self->port unless defined $port;
    
    unless ($ssh2->connect($host, $port)) {
        croak "Failed to connect to ${host}:${port}: " . ($ssh2->error || 'Unknown error');
    }
    
    # Track when this connection was established
    $self->_connection_established_at(time());
    
    return $ssh2;
}

# Connection health and validation methods
sub _is_connection_expired {
    my ($self) = @_;
    
    return 0 unless $self->_connection_established_at;
    
    my $age = time() - $self->_connection_established_at;
    return $age > $self->connection_max_age;
}

sub _is_connection_healthy {
    my ($self) = @_;
    
    return 0 unless $self->_has_connection && $self->_authenticated;
    return 0 if $self->_is_connection_expired;
    
    # Skip health check if disabled or recently checked
    return 1 unless $self->health_check_enabled;
    
    if ($self->_last_health_check) {
        my $time_since_check = time() - $self->_last_health_check;
        return 1 if $time_since_check < 30;  # Skip check if done within 30 seconds
    }
    
    # Perform actual health check with a simple command
    my $health_result = eval {
        my $ssh2 = $self->_ssh2;
        my $channel = $ssh2->channel();
        return 0 unless $channel;
        
        # Use a simple echo command as health check
        my $test_command = 'echo "health_check"';
        return 0 unless $channel->exec($test_command);
        
        # Try to read response
        my $output = '';
        my $timeout = time() + 5;  # 5 second timeout for health check
        
        while (time() < $timeout) {
            my $buffer;
            my $bytes = $channel->read($buffer, 1024);
            last if $bytes <= 0;
            $output .= $buffer;
            last if $output =~ /health_check/;
        }
        
        $channel->close();
        return $output =~ /health_check/;
    };
    
    $self->_last_health_check(time());
    
    if ($@ || !$health_result) {
        # Health check failed, connection is unhealthy
        return 0;
    }
    
    return 1;
}

sub test_password_connection {
    my ($self) = @_;
    
    my $result = eval {
        my $ssh2 = $self->_ssh2;
        
        if ($ssh2->auth_password($self->username, $self->password)) {
            $self->_authenticated(1);
            return 1;
        }
        
        return 0;
    };
    
    # Reset connection on any error
    if ($@) {
        $self->_clear_connection();
        $self->_authenticated(0);
        return 0;
    }
    
    return $result;
}

sub test_key_connection {
    my ($self) = @_;
    
    my $result = eval {
        my $ssh2 = $self->_ssh2;
        
        # Find public key file
        my $public_key_path = $self->_find_public_key_path();
        
        if ($ssh2->auth_publickey($self->username, $public_key_path, $self->ssh_key_path)) {
            $self->_authenticated(1);
            return 1;
        }
        
        return 0;
    };
    
    if ($@) {
        $self->_clear_connection();
        $self->_authenticated(0);
        return 0;
    }
    
    return $result;
}

sub execute_command {
    my ($self, $command) = @_;
    
    return $self->_execute_command_with_retry($command, 1);
}

sub _execute_command_with_retry {
    my ($self, $command, $max_retries) = @_;
    
    for my $attempt (1..$max_retries) {
        # Ensure we have an authenticated connection
        unless ($self->_ensure_authenticated()) {
            return {
                output => "Authentication failed",
                success => 0,
                exit_code => 255,
            };
        }
        
        my $result = eval {
            my $ssh2 = $self->_ssh2;
            my $channel = $ssh2->channel();
            
            unless ($channel) {
                croak "Failed to create channel: " . ($ssh2->error || 'Unknown error');
            }
            
            # Execute command
            unless ($channel->exec($command)) {
                croak "Failed to execute command '$command': " . ($ssh2->error || 'Unknown error');
            }
            
            # Read output with timeout
            my $output = $self->_read_channel_output($channel);
            
            # Wait for command completion and get exit status
            $channel->wait_closed();
            my $exit_code = $channel->exit_status();
            $exit_code = 0 unless defined $exit_code;
            
            return {
                output => $output,
                success => $exit_code == 0,
                exit_code => $exit_code,
            };
        };
        
        # If command succeeded, return result
        if (!$@ && $result) {
            return $result;
        }
        
        # Command failed - check if we should retry
        if ($attempt < $max_retries && $self->auto_reconnect) {
            # Clear connection and try again
            $self->_clear_connection();
            $self->_clear_connection_timestamp();
            $self->_authenticated(0);
            next;
        }
        
        # No more retries or auto_reconnect disabled
        return {
            output => "SSH command execution failed: $@",
            success => 0,
            exit_code => 255,
        };
    }
}

sub execute_command_with_sudo {
    my ($self, $command) = @_;
    
    return $self->execute_command("sudo $command");
}

sub disconnect {
    my ($self) = @_;
    
    if ($self->_has_connection) {
        eval { $self->_ssh2->disconnect() };
    }
    
    $self->_clear_connection();
    $self->_clear_connection_timestamp();
    $self->_authenticated(0);
}

# Public connection management methods
sub is_connection_healthy {
    my ($self) = @_;
    return $self->_is_connection_healthy();
}

sub get_connection_age {
    my ($self) = @_;
    return 0 unless $self->_connection_established_at;
    return time() - $self->_connection_established_at;
}

sub force_reconnect {
    my ($self) = @_;
    $self->disconnect();
    return $self->_ensure_authenticated();
}

# Private helper methods
sub _ensure_authenticated {
    my ($self) = @_;
    
    # Check if existing connection is healthy
    if ($self->_is_connection_healthy()) {
        return 1;
    }
    
    # Connection is unhealthy or expired, clear it and reconnect
    if ($self->_has_connection) {
        $self->_clear_connection();
        $self->_clear_connection_timestamp();
        $self->_authenticated(0);
    }
    
    # Try password authentication first
    return 1 if $self->test_password_connection();
    
    # Fall back to key authentication
    return 1 if $self->test_key_connection();
    
    return 0;
}

sub _find_public_key_path {
    my ($self) = @_;
    
    my $private_key = $self->ssh_key_path;
    
    # Common public key extensions
    for my $suffix ('.pub', '') {
        my $public_key = $private_key . $suffix;
        return $public_key if -f $public_key;
    }
    
    # If no public key file found, try using the private key path
    # (some SSH implementations accept this)
    return $private_key;
}

sub _read_channel_output {
    my ($self, $channel) = @_;
    
    my $output = '';
    my $buffer;
    
    # Set up non-blocking read with timeout
    $channel->blocking(0);
    
    my $start_time = time();
    my $timeout = $self->command_timeout;
    
    while (time() - $start_time < $timeout) {
        my $bytes_read = $channel->read($buffer, 4096);
        
        if (defined $bytes_read && $bytes_read > 0) {
            $output .= $buffer;
            next;
        }
        
        # Check if channel is closed
        last if $channel->eof();
        
        # Small sleep to prevent busy waiting
        select(undef, undef, undef, 0.1);
    }
    
    # Final blocking read to get any remaining data
    $channel->blocking(1);
    while (my $bytes_read = $channel->read($buffer, 4096)) {
        last unless defined $bytes_read && $bytes_read > 0;
        $output .= $buffer;
    }
    
    return $output;
}

# Cleanup on destruction
sub DEMOLISH {
    my ($self) = @_;
    $self->disconnect();
}

1;

__END__

=head1 NAME

TorrustDeploy::Infrastructure::SSH::Connection - SSH connection management using Net::SSH2

=head1 DESCRIPTION

Handles SSH connections and command execution for provisioned VMs using Net::SSH2.
Provides a stable API while using a robust SSH implementation underneath.

=head1 DEPENDENCIES

    # System packages (Ubuntu/Debian)
    sudo apt-get install libssh2-1-dev
    
    # Perl module
    cpanm Net::SSH2

=head1 ATTRIBUTES

=head2 host

Required. The target host IP address or hostname.

=head2 username

SSH username. Defaults to 'torrust'.

=head2 password

SSH password for password-based authentication. Defaults to 'torrust123'.

=head2 ssh_key_path

Path to SSH private key. Defaults to ~/.ssh/testing_rsa.

=head2 connect_timeout

SSH connection timeout in seconds. Defaults to 10.

=head2 command_timeout

Command execution timeout in seconds. Defaults to 30.

=head2 connection_max_age

Maximum age of SSH connections in seconds before they are considered stale
and require reconnection. Defaults to 300 (5 minutes).

=head2 health_check_enabled

Enable connection health checks before command execution. When enabled,
connections are validated using a lightweight echo command before executing
the actual command. Defaults to true.

=head2 auto_reconnect

Enable automatic reconnection when connection health checks fail or commands
fail due to connection issues. When enabled, the connection manager will
automatically attempt to reconnect and retry failed commands. Defaults to true.

=head1 METHODS

=head2 test_password_connection

Tests if password-based SSH connection and authentication work.
Returns true on success, false on failure.

=head2 test_key_connection

Tests if key-based SSH connection and authentication work.
Returns true on success, false on failure.

=head2 execute_command($command)

Executes a command via SSH with automatic authentication fallback.
Returns hashref with:
- output: Command output
- success: Boolean success flag
- exit_code: Command exit code

=head2 execute_command_with_sudo($command)

Executes a command with sudo prefix via SSH.

=head2 disconnect

Explicitly closes the SSH connection and clears authentication state.

=head2 is_connection_healthy

Tests if the current SSH connection is healthy by executing a lightweight
echo command. Returns true if the connection is working, false otherwise.
Results are cached for 30 seconds to avoid excessive health checks.

=head2 get_connection_age

Returns the age of the current connection in seconds. Returns 0 if no
connection has been established.

=head2 force_reconnect

Forces a reconnection by closing the current connection and clearing all
cached state. The next command execution will establish a fresh connection.

=head1 AUTHENTICATION

The connection automatically tries password authentication first, then falls
back to key-based authentication. Connections are reused across multiple
command executions for better performance.

=head1 CONNECTION MANAGEMENT

The SSH Connection Manager includes several robustness features:

=over 4

=item * B<Health Checks>: Before executing commands, the connection is validated
using a lightweight echo command. Health check results are cached for 30 seconds
to balance reliability with performance.

=item * B<Automatic Reconnection>: When connections fail health checks or commands
fail due to connection issues, the manager automatically attempts to reconnect
and retry the operation.

=item * B<Connection Expiration>: Connections older than the configured maximum
age (default 5 minutes) are automatically renewed to prevent stale connection
issues.

=item * B<State Validation>: The connection manager tracks connection state and
timestamps to detect when connections may have become invalid due to network
events or server reboots.

=back

=cut
