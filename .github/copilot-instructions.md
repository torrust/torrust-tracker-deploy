# Torrust Tracker Deployment Tool

A modern Perl console application for deploying Torrust Tracker to Hetzner Cloud using Packer, Terraform, and Ansible.

## Code Quality Standards

### Perl Code Organization

Follow [perlstyle](https://perldoc.perl.org/5.42.0/perlstyle) conventions for consistent, readable code.

#### Core Requirements

- **Always use strict and warnings**: `use strict; use warnings;` or `use v5.36;` (enables both)
- **Modern Perl**: Use `use v5.40;` or higher for modern features (enables strict, warnings, and more)

#### Naming Conventions

- **Package names**: Mixed case starting with capital letter, no underscores

  - Example: `TorrustDeploy::App::Command::Provision`
  - Lowercase reserved for pragmas (`strict`, `warnings`, `integer`)

- **Variable naming by scope**:

  - `$ALL_CAPS_HERE` - constants only
  - `$Some_Caps_Here` - package-wide global/static variables
  - `$no_caps_here` - function scope `my()` or `local()` variables

- **Function and method names**: All lowercase with underscores

  - Example: `$obj->as_string()`, `provision_infrastructure()`

- **Leading underscore**: Indicates private/internal use only
  - Example: `_internal_helper()`, `$_private_var`

#### Directory Structure

- **Module directories (`lib/`)**: CamelCase following package names

  - Example: `lib/TorrustDeploy/App/Command/Provision.pm`
  - Each `::` separator becomes a directory `/` in the filesystem

- **Test directories (`t/`)**: Lowercase with hyphens or underscores

  - Example: `t/001-basic.t`, `t/provision-command.t`, `t/integration/tofu-provider.t`
  - Follow established Perl testing conventions

- **Standard project directories**: Use lowercase

  - `lib/`, `bin/`, `t/`, `xt/`, `share/`, `templates/`, `script/`, `build/`

- **General project directories**: Use lowercase with underscores for separation
  - Example: `cloud_init/`, `user_data/`, `config_templates/`

#### Code Style

- **Indentation**: 4-column indent
- **Braces**: Opening curly on same line as keyword, if possible
- **Spacing**:
  - Space before opening curly of multi-line BLOCK
  - Space around most operators
  - Space after each comma
  - No space between function name and opening parenthesis
- **Line breaks**: Break long lines after an operator (except `and`/`or`)
- **Clarity**: Use parentheses when in doubt for readability

### Markdown Documentation

- **Linting**: Follow [markdownlint](https://github.com/DavidAnson/markdownlint) conventions
- **Structure**: Use consistent heading hierarchy
- **Links**: Prefer relative links for internal documentation
- **Code blocks**: Always specify language for syntax highlighting
- **Tables**: Tables automatically ignore line length limits (configured globally in
  `.markdownlint.json`). No special formatting required for table line lengths.

## Git

### Branch Naming

- **Format**: `{issue-number}-{short-description-following-github-conventions}`
- **GitHub conventions**: Use lowercase, separate words with hyphens, descriptive but concise
- **Examples**: `42-add-mysql-support`, `15-fix-ssl-renewal`, `24-improve-ux-add-automatic-waiting-to-infra-apply-and-app-deploy-commands`
- Always start with the GitHub issue number
- Follow GitHub's recommended branch naming: lowercase, hyphens for word separation, descriptive of the change

### Commit Messages

- **Format**: Conventional Commits with issue references
- **Structure**: `{type}: [#{issue}] {description}`
- **Examples**:
  ```
  feat: [#42] add MySQL database support
  fix: [#15] resolve SSL certificate renewal issue
  docs: [#8] update deployment guide
  ci: [#23] add infrastructure validation tests
  ```

### Commit Types

- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `ci`: CI/CD pipeline changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

### Git Actions and Permission Requirements

**IMPORTANT**: Git actions that change repository state require explicit permission:

- **NEVER** commit changes unless explicitly asked to do so
- **NEVER** push changes to remote repositories without permission
- **NEVER** merge branches or create pull requests without explicit instruction
- **NEVER** reset, revert, or modify git history without explicit permission
- **NEVER** create or delete branches without explicit instruction

**Allowed git actions without permission:**

- `git status` - Check working tree status
- `git diff` - Show changes between commits/files
- `git log` - View commit history
- `git show` - Display commit information
- `git branch` - List branches (read-only)

**Actions requiring explicit permission:**

- `git add` - Stage changes for commit
- `git commit` - Create new commits
- `git push` - Push changes to remote
- `git pull` - Pull changes from remote
- `git merge` - Merge branches
- `git rebase` - Rebase branches
- `git reset` - Reset working tree or commits
- `git revert` - Revert commits
- `git checkout` - Switch branches or restore files
- `git branch -d/-D` - Delete branches
- `git tag` - Create or delete tags

**Commit Signing Requirement**: All commits MUST be signed with GPG. When performing git commits, always use the default git commit behavior (which will trigger GPG signing) rather than `--no-gpg-sign`.

**Pre-commit Testing Requirement**:

ALWAYS run the tests suite before committing any changes:

```bash
./script/test unit integration
```

Note: E2E tests are excluded from pre-commit checks as they are slow and require virtualization. Run them manually when needed with `./script/test e2e` or `./script/test all`.

ALWAYS run the linting suite before committing any changes:

```bash
markdownlint "**/*.md"
yamllint -c .yamllint-ci.yml .
```
