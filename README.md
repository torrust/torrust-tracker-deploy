[![Testing](https://github.com/torrust/torrust-tracker-deploy/actions/workflows/testing.yml/badge.svg)](https://github.com/torrust/torrust-tracker-deploy/actions/workflows/testing.yml)

# Torrust Tracker Deployment Tool

A modern Perl console application for deploying Torrust Tracker to Hetzner Cloud using Packer,
Terraform, and Ansible.

## Installation

Install cpanminus:

```bash
curl -L https://cpanmin.us | perl - --sudo App::cpanminus
```

Install local::lib:

```bash
cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
```

Install Carmel dependency manager:

```bash
cpanm Carmel
```

Set up the environment (add carmel to PATH and set PERL5LIB):

```bash
eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
export PATH="$HOME/perl5/bin:$PATH"
```

**Note:** You need to run the `eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)` command in each new
terminal session, or add it to your shell profile (`.bashrc`, `.zshrc`, etc.).

Then install project dependencies:

```bash
carmel install
```

## Usage

Run the application:

```bash
carmel exec -- ./bin/torrust-deploy help
```

## Testing

Run the test suite:

```bash
carmel exec -- prove -l t/
```
