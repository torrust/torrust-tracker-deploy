package TorrustDeploy::App::Command::help;

use strict;
use warnings;
use v5.20;

use TorrustDeploy::App -command;

sub abstract { "Show help information" }

sub description { 
    return <<'END_DESCRIPTION';
This is the Torrust Tracker deployment tool for Hetzner Cloud.

A modern Perl console application for deploying Torrust Tracker using Packer, Terraform, and Ansible.

Use 'torrust-deploy help <command>' for specific command help.
END_DESCRIPTION
}

sub execute {
    my ($self, $opt, $args) = @_;
    
    if (@$args) {
        # Show help for specific command
        my $command = $args->[0];
        
        # Prevent infinite recursion when asking for help about help
        if ($command eq 'help') {
            print "The 'help' command shows information about available commands.\n";
            print "Usage: torrust-deploy help [<command>]\n";
            print "  torrust-deploy help        - Show general help\n";
            print "  torrust-deploy help <cmd>  - Show help for specific command\n";
            return;
        }
        
        $self->app->execute_command(
            $self->app->prepare_command($command, '--help')
        );
    } else {
        # Show general help
        print $self->description;
        print "\nAvailable commands:\n";
        
        my @commands = sort $self->app->command_names;
        for my $cmd (@commands) {
            next if $cmd eq 'help';
            printf "  %-12s %s\n", $cmd, "Command description";
        }
        print "\nUse 'torrust-deploy help <command>' for more information on a specific command.\n";
    }
}

1;

__END__

=head1 NAME

TorrustDeploy::App::Command::help - Help command for TorrustDeploy

=head1 DESCRIPTION

Provides help information for the TorrustDeploy application and its commands.

=cut
