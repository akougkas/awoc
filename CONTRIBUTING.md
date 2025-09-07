# Contributing to AWOC

Thank you for your interest in contributing to AWOC! This document provides guidelines and information for contributors.

## Development Philosophy

AWOC follows **incremental development** principles:
- Start with minimal, working solutions
- Add complexity only when proven necessary
- Focus on developer experience and reliability
- Keep the codebase simple and maintainable

## Getting Started

### Prerequisites
- Git
- Bash (Unix-like shell)
- Basic understanding of Claude Code/OpenCode/Gemini CLI

### Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/awoc.git
cd awoc

# Validate installation
./validate.sh

# Make your changes
# ... development work ...

# Test your changes
./validate.sh
```

## Contribution Types

### 🐛 Bug Fixes
- Fix issues in existing functionality
- Include test cases that reproduce the bug
- Ensure all existing tests still pass

### ✨ New Features
- Start with a clear problem statement
- Implement minimal viable solution first
- Add comprehensive documentation
- Include usage examples

### 📚 Documentation
- Improve existing documentation
- Add examples and tutorials
- Fix typos and clarify confusing sections

### 🧪 Testing
- Add test cases for new functionality
- Improve test coverage
- Fix failing tests

## Development Workflow

### 1. Choose an Issue
- Check existing [issues](../../issues) for something to work on
- Create a new issue if you have a specific improvement in mind
- Comment on the issue to indicate you're working on it

### 2. Create a Branch
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number-description
```

### 3. Make Changes
- Follow the existing code style and patterns
- Keep commits atomic and well-described
- Test your changes thoroughly

### 4. Test Your Changes
```bash
# Run validation
./validate.sh

# Test installation
./install.sh

# Verify in a test project
awoc init
awoc session start "Testing changes"
```

### 5. Submit a Pull Request
- Ensure your branch is up to date with main
- Write a clear PR description
- Reference any related issues
- Request review from maintainers

## Code Standards

### General Guidelines
- Use clear, descriptive names
- Add comments for complex logic
- Follow existing patterns in the codebase
- Keep files focused on single responsibilities

### File Organization
```
awoc/
├── agents/           # Agent definitions
├── commands/         # Command implementations
├── output-styles/    # Output behavior patterns
├── docs/            # Documentation
├── settings.json    # Configuration
└── *.sh             # Scripts
```

### Agent Development
- Use YAML frontmatter for metadata
- Include clear tool specifications
- Document collaboration protocols
- Focus on specific, narrow responsibilities

### Command Development
- Use markdown with YAML frontmatter
- Include argument hints
- Specify allowed tools
- Keep commands focused and simple

## Testing

### Manual Testing
- Test in different CLI environments (Claude Code, OpenCode, Gemini CLI)
- Verify installation process
- Test session start/end workflows
- Check agent activation and responses

### Validation
- Run `./validate.sh` before committing
- Ensure all required files are present
- Verify JSON syntax is valid
- Check script permissions

## Commit Guidelines

### Commit Message Format
```
type(scope): description

[optional body]

[optional footer]
```

### Types
- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Testing changes
- `chore`: Maintenance tasks

### Examples
```
feat(api-researcher): Add caching for API documentation

- Cache API responses locally
- Reduce external API calls
- Improve response times

Closes #123
```

```
fix(session-start): Handle uncommitted changes properly

Previously would fail silently when git status was dirty.
Now provides clear error message and suggests solutions.
```

## Release Process

### Version Numbering
AWOC follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist
- [ ] Update version in `settings.json`
- [ ] Update `CHANGELOG.md`
- [ ] Create git tag
- [ ] Test installation process
- [ ] Update documentation if needed

## Community

### Discussion
- Use [GitHub Discussions](../../discussions) for questions
- Join development conversations
- Share your use cases and feedback

### Support
- Check existing issues before creating new ones
- Provide clear reproduction steps for bugs
- Include your environment details
- Be patient and respectful

## Recognition

Contributors will be:
- Listed in `CHANGELOG.md` for their contributions
- Recognized in release notes
- Invited to join the core team for significant contributions

Thank you for contributing to AWOC! 🎉