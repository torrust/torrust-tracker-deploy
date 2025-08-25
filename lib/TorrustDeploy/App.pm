package TorrustDeploy::App;

use strict;
use warnings;
use v5.20;

# App::Cmd framework setup - automatically discovers commands in TorrustDeploy::App::Command::*
# Commands are found by convention: each .pm file in lib/TorrustDeploy/App/Command/ 
# becomes a command (e.g., help.pm -> "help" command, packer.pm -> "packer" command)
use App::Cmd::Setup -app;

1;

__END__

=head1 NAME

TorrustDeploy::App - Deploy Torrust Tracker to Hetzner Cloud

=head1 DESCRIPTION

A modern Perl console application for deploying Torrust Tracker to Hetzner Cloud
using Packer, Terraform, and Ansible.

=head1 AUTHOR

Torrust Team

=head1 LICENSE

This software is released under the MIT license.

=cut
