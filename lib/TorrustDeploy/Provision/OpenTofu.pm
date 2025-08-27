package TorrustDeploy::Provision::OpenTofu;

use v5.38;

use JSON;

=head1 NAME

TorrustDeploy::Provision::OpenTofu - OpenTofu command wrapper for Torrust deployment

=head1 DESCRIPTION

This package provides methods to interact with OpenTofu (Terraform fork) for
infrastructure provisioning. It handles initialization, applying configurations,
and extracting outputs.

=head1 METHODS

=cut

=head2 new

Create a new OpenTofu instance.

=cut

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

=head2 init

Initialize OpenTofu in the specified directory.

    $tofu->init($tofu_dir);

=cut

sub init {
    my ($self, $tofu_dir) = @_;
    
    say "Initializing OpenTofu...";
    
    my $result = system("cd '$tofu_dir' && tofu init");
    if ($result != 0) {
        die "OpenTofu init failed with exit code: $result";
    }
    
    say "OpenTofu initialized successfully.";
}

=head2 apply

Apply OpenTofu configuration in the specified directory.

    $tofu->apply($tofu_dir);

=cut

sub apply {
    my ($self, $tofu_dir) = @_;
    
    say "Applying OpenTofu configuration...";
    say "This may take a few minutes to download the base image and create the VM...";
    
    my $result = system("cd '$tofu_dir' && tofu apply -auto-approve");
    if ($result != 0) {
        die "OpenTofu apply failed with exit code: $result";
    }
    
    say "";
    say "OpenTofu apply completed successfully.";
}

=head2 get_vm_ip

Get the VM IP address from OpenTofu outputs.

    my $ip = $tofu->get_vm_ip($tofu_dir);

Returns the IP address as a string.

=cut

sub get_vm_ip {
    my ($self, $tofu_dir) = @_;
    
    say "Getting VM IP address...";
    STDOUT->flush(); # Force flush output buffer
    
    # Capture stdout only, handle stderr separately
    my $cmd = "cd '$tofu_dir' && tofu output -json";
    my $output = `$cmd`;
    my $exit_code = $? >> 8;
    
    if ($exit_code != 0) {
        # If command failed, capture stderr for better error reporting
        my $error_cmd = "cd '$tofu_dir' && tofu output -json 2>&1";
        my $error_output = `$error_cmd`;
        die "Failed to get OpenTofu outputs (exit code: $exit_code). Output: $error_output";
    }
    
    # Check if we have any output
    unless ($output && $output =~ /\S/) {
        die "No output received from OpenTofu command";
    }
    
    # Try to parse JSON with proper error handling
    my $outputs;
    eval {
        $outputs = decode_json($output);
    };
    if ($@) {
        die "Failed to parse OpenTofu output as JSON: $@\nOutput was: $output";
    }
    
    # Extract VM IP
    my $vm_ip = $outputs->{vm_ip}{value};
    
    unless ($vm_ip) {
        die "Could not retrieve VM IP address from OpenTofu outputs. Available outputs: " . join(", ", keys %$outputs);
    }
    
    say "VM IP address: $vm_ip";
    STDOUT->flush(); # Force flush output buffer
    return $vm_ip;
}

1;

__END__

=head1 AUTHOR

Torrust Team

=head1 LICENSE

This software is licensed under the MIT License.

=cut
