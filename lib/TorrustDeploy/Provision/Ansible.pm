package TorrustDeploy::Provision::Ansible;

use v5.38;

use Path::Tiny qw(path);

=head1 NAME

TorrustDeploy::Provision::Ansible - Ansible command wrapper for Torrust deployment

=head1 DESCRIPTION

This package provides methods to interact with Ansible for post-provision
verification and configuration. It handles copying templates, inventory 
generation, and running playbooks.

=head1 METHODS

=cut

=head2 new

Create a new Ansible instance.

=cut

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

=head2 copy_templates_and_generate_inventory

Copy Ansible templates to working directory and generate inventory with VM IP.

    $ansible->copy_templates_and_generate_inventory($vm_ip, $ansible_dir);

=cut

sub copy_templates_and_generate_inventory {
    my ($self, $vm_ip, $ansible_dir) = @_;
    
    say "Setting up Ansible configuration...";
    
    # Ensure ansible directory exists
    $ansible_dir->mkpath unless $ansible_dir->exists;
    
    my $templates_dir = path('templates/ansible');
    
    # Check if templates directory exists
    unless ($templates_dir->exists) {
        die "Ansible templates directory not found: $templates_dir";
    }
    
    # Copy ansible.cfg
    my $ansible_cfg_template = $templates_dir->child('ansible.cfg');
    my $ansible_cfg_dest = $ansible_dir->child('ansible.cfg');
    
    unless ($ansible_cfg_template->exists) {
        die "Ansible config template not found: $ansible_cfg_template";
    }
    
    $ansible_cfg_template->copy($ansible_cfg_dest);
    say "Copied: $ansible_cfg_template -> $ansible_cfg_dest";
    
    # Copy playbooks
    my $verification_template = $templates_dir->child('post-provision-verification.yml');
    my $verification_dest = $ansible_dir->child('post-provision-verification.yml');
    
    unless ($verification_template->exists) {
        die "Verification playbook template not found: $verification_template";
    }
    
    $verification_template->copy($verification_dest);
    say "Copied: $verification_template -> $verification_dest";
    
    # Generate inventory with VM IP
    my $inventory_template = $templates_dir->child('inventory.ini.template');
    my $inventory_dest = $ansible_dir->child('inventory.ini');
    
    unless ($inventory_template->exists) {
        die "Inventory template not found: $inventory_template";
    }
    
    # Read template and replace VM_IP placeholder
    my $inventory_content = $inventory_template->slurp_utf8;
    $inventory_content =~ s/\{\{VM_IP\}\}/$vm_ip/g;
    
    # Write the generated inventory
    $inventory_dest->spew_utf8($inventory_content);
    say "Generated inventory: $inventory_dest (VM IP: $vm_ip)";
    
    say "Ansible setup completed successfully.";
}

=head2 run_verification

Run the post-provision verification playbook.

    $ansible->run_verification($ansible_dir);

=cut

sub run_verification {
    my ($self, $ansible_dir) = @_;
    
    say "🔍 Running Ansible post-provision verification...";
    STDOUT->flush();
    
    # Change to ansible directory and run playbook
    my $result = system("cd '$ansible_dir' && ansible-playbook -i inventory.ini post-provision-verification.yml");
    
    if ($result != 0) {
        die "Ansible verification failed with exit code: $result";
    }
    
    say "✅ Ansible verification completed successfully!";
    STDOUT->flush();
}

1;

__END__

=head1 AUTHOR

Torrust Team

=head1 LICENSE

This software is licensed under the MIT License.

=cut
