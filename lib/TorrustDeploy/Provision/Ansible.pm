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
    
    # Copy all playbooks
    my @playbooks = (
        'wait-for-cloud-init.yml',
        'post-provision-verification.yml',
        'restart-vm.yml'
    );
    
    for my $playbook (@playbooks) {
        my $template = $templates_dir->child($playbook);
        my $dest = $ansible_dir->child($playbook);
        
        unless ($template->exists) {
            die "Playbook template not found: $template";
        }
        
        $template->copy($dest);
        say "Copied: $template -> $dest";
    }
    
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

=head2 wait_for_cloud_init

Wait for cloud-init completion using Ansible playbook.

    $ansible->wait_for_cloud_init($ansible_dir);

=cut

sub wait_for_cloud_init {
    my ($self, $ansible_dir) = @_;
    
    say "⏳ Waiting for cloud-init completion using Ansible...";
    STDOUT->flush();
    
    # Change to ansible directory and run cloud-init wait playbook
    my $result = system("cd '$ansible_dir' && ansible-playbook -i inventory.ini wait-for-cloud-init.yml");
    
    if ($result != 0) {
        die "Ansible cloud-init wait failed with exit code: $result";
    }
    
    say "✅ Cloud-init completion verified via Ansible!";
    STDOUT->flush();
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

=head2 restart_vm

Restart the VM after post-provision verification.

    $ansible->restart_vm($ansible_dir);

=cut

sub restart_vm {
    my ($self, $ansible_dir) = @_;
    
    say "🔄 Restarting VM using Ansible...";
    STDOUT->flush();
    
    # Change to ansible directory and run restart playbook
    my $result = system("cd '$ansible_dir' && ansible-playbook -i inventory.ini restart-vm.yml");
    
    if ($result != 0) {
        die "Ansible VM restart failed with exit code: $result";
    }
    
    say "✅ VM restart completed successfully!";
    STDOUT->flush();
}

1;

__END__

=head1 AUTHOR

Torrust Team

=head1 LICENSE

This software is licensed under the MIT License.

=cut
