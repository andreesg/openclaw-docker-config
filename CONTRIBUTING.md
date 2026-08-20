# Contributing to OpenClaw Terraform Hetzner

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Bugs

Before creating a bug report:
- Check the existing issues to avoid duplicates
- Collect information about the bug (Terraform version, Hetzner provider version, error messages)

When creating a bug report, include:
- **Clear title** describing the issue
- **Steps to reproduce** the problem
- **Expected behavior** vs actual behavior
- **Environment details** (OS, Terraform version, provider versions)
- **Error messages** (full output if possible)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:
- Use a clear, descriptive title
- Provide a detailed description of the proposed functionality
- Explain why this enhancement would be useful
- Include examples of how it would be used

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Follow code style**:
   - Run `terraform fmt -recursive` before committing
   - Use meaningful variable and resource names
   - Add comments for complex logic
3. **Test your changes**:
   - Test with a fresh deployment
   - Verify existing functionality still works
   - Document any new configuration requirements
4. **Update documentation**:
   - Update README.md if adding new features
   - Add/update comments in code
   - Update example configurations if needed
5. **Commit with clear messages**:
   - Use the present tense ("Add feature" not "Added feature")
   - Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
   - Reference issues and pull requests when relevant

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/openclaw-terraform-hetzner.git
cd openclaw-terraform-hetzner

# Configure inputs
cp config/inputs.example.sh config/inputs.sh
vim config/inputs.sh  # Add your Hetzner API token

# Test your changes
source config/inputs.sh
make init
make plan
```

### Code Style

**Terraform:**
- Use `terraform fmt` for formatting
- Follow [HashiCorp Style Guide](https://developer.hashicorp.com/terraform/language/style)
- Use descriptive resource names
- Add descriptions to all variables and outputs

**Shell Scripts:**
- Use `shellcheck` for linting
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `set -euo pipefail` at the top of scripts
- Add comments for non-obvious logic

### Testing

Before submitting a pull request:

1. **Syntax validation:**
   ```bash
   terraform fmt -check -recursive
   shellcheck scripts/*.sh deploy/*.sh
   ```

2. **Functional testing:**
   - Test `make init && make plan && make apply`
   - Test deployment scripts (bootstrap, deploy)
   - Verify cleanup with `make destroy`

3. **Documentation:**
   - Verify README examples work
   - Check all links are valid
   - Ensure new features are documented

## Project Structure

```
.
├── infra/terraform/      # Terraform configuration
│   ├── globals/          # Shared configuration
│   ├── envs/prod/        # Production environment
│   └── modules/          # Reusable modules
├── deploy/               # Deployment scripts
├── scripts/              # Utility scripts
├── config/               # Configuration templates
└── secrets/              # Secret templates (.gitignored)
```

## Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `chore:` Maintenance tasks
- `refactor:` Code refactoring
- `test:` Adding or updating tests

Examples:
```
feat: add support for custom firewall rules
fix: correct cloud-init user data template
docs: improve quick start guide
chore: update Terraform provider version
```

## Community

- Be respectful and constructive in discussions
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md)
- Help others in issues and discussions
- Share your deployment experiences

## Questions?

- Open a [GitHub Discussion](../../discussions) for questions
- Check existing issues and discussions first
- Use issues only for bugs and feature requests

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
