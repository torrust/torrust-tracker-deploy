# Torrust Tracker Deployment Tool

A modern Perl console application for deploying Torrust Tracker to Hetzner Cloud using Packer, Terraform, and Ansible.

## Code Quality Standards

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
carmel exec -- prove -l t/
```

ALWAYS run the linting suite before committing any changes:

```bash
markdownlint "**/*.md"
yamllint -c .yamllint-ci.yml .
```
