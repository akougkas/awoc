# Contributing to AWOC

Thank you for your interest in contributing to AWOC! We're excited to have you join our community of developers building the future of AI-assisted development.

## 🎯 Quick Start

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/YOUR-USERNAME/awoc`
3. **Branch**: `git checkout -b feature/your-feature`
4. **Test**: `awoc validate`
5. **Push**: `git push origin feature/your-feature`
6. **PR**: Open a pull request with a clear description

## 🌟 Priority Areas

We especially welcome contributions in these areas:

### Domain-Specific Agent Packs
- **Biology/Life Sciences**: Lab workflows, data analysis, paper writing
- **Finance/Trading**: Market analysis, risk assessment, reporting
- **Education**: Course creation, grading assistance, tutoring
- **Creative Arts**: Story writing, music composition, visual arts
- **DevOps/SRE**: Infrastructure management, monitoring, automation

### Tool Integrations
- Jupyter notebooks
- Docker/Kubernetes
- Cloud providers (AWS, Azure, GCP)
- Database systems
- CI/CD pipelines

### Documentation & Tutorials
- Video tutorials
- Blog posts about your AWOC setup
- Translation to other languages
- Domain-specific guides

## 📝 Contribution Guidelines

### Code Style
- Use bash for scripts (shellcheck compliant)
- JSON configuration files (validate with jq)
- Markdown for documentation and agents
- Clear, descriptive variable names
- Comments for complex logic only

### Testing Requirements
- All changes must pass `awoc validate`
- Test in actual Claude Code/AI assistant
- Include test cases for new features
- Document any special setup required

### Commit Messages
```
feat: Add biology domain pack with 5 specialized agents
fix: Correct hooks format for Claude Code 2025
docs: Add tutorial for data science workflows
refactor: Simplify agent priming logic
```

### Pull Request Process
1. **Title**: Clear, descriptive title
2. **Description**: What, why, and how
3. **Examples**: Show usage examples
4. **Testing**: Describe testing performed
5. **Checklist**: Complete PR checklist

## 🏗️ Project Structure

```
awoc/
├── agents/           # Core specialized AI agents (6 included)
├── commands/         # Slash commands for AI assistants
│   └── priming/     # Dynamic context loading commands
├── domains/          # Domain-specific packs
│   ├── coding/      # Programming enhancements (started)
│   └── writing/     # Content creation tools (started)
├── scripts/          # Utility bash scripts
├── templates/        # Templates for agents and commands
├── awoc             # Main CLI script
└── settings.json    # Configuration template
```

## 🧪 Testing Your Changes

### Local Testing
```bash
# Validate your changes
./validate.sh

# Test installation
./install.sh

# Deploy to test project
awoc install -d ~/test-project

# Open Claude Code and test
cd ~/test-project
# Run /awoc-help and test your features
```

### Integration Testing
1. Test with fresh installation
2. Test upgrade from previous version
3. Test on different OS (Linux/macOS)
4. Test with different AI assistants

## 💡 Creating Domain Packs

### Structure
```
domains/your-domain/
├── agents/           # Domain-specific agents (optional)
│   ├── specialist-1.md
│   └── specialist-2.md
├── commands/         # Domain workflows (optional)
│   └── workflow.md
├── README.md        # How to use your pack (required)
└── examples/        # Usage examples (recommended)
```

### Current Domains
- **coding/** - Programming-specific enhancements
- **writing/** - Content creation and editing tools

### Creating Your Domain Pack
1. **Choose your domain**: `mkdir -p domains/biology`
2. **Add specialized agents**: Copy and modify from `agents/`
3. **Create workflows**: Add domain-specific commands
4. **Document thoroughly**: Write clear README.md
5. **Test in real projects**: Validate with `awoc validate`
6. **Submit PR**: Share with the community

## 🐛 Reporting Issues

### Before Reporting
- Check existing issues
- Try `awoc doctor` for diagnostics
- Read TROUBLESHOOTING.md
- Update to latest version

### Issue Template
```markdown
**Description**: Clear description of the issue
**Steps to Reproduce**: 1. 2. 3.
**Expected**: What should happen
**Actual**: What actually happens
**Environment**: OS, Claude Code version, AWOC version
**Logs**: Relevant error messages
```

## 🤝 Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Provide constructive feedback
- Focus on what is best for the community
- Show empathy towards others

## 📚 Resources

- [AGENTS.md](AGENTS.md) - AI agent instructions
- [CLAUDE.md](CLAUDE.md) - Development documentation
- [FEATURES.md](FEATURES.md) - Feature status
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues

## 🏆 Recognition

Contributors are recognized in:
- README.md credits section
- Release notes
- Special badges for significant contributions
- Direct collaboration opportunities

## ❓ Questions?

- Open a [Discussion](https://github.com/akougkas/awoc/discussions)
- Check the [Wiki](https://github.com/akougkas/awoc/wiki)
- Review [existing PRs](https://github.com/akougkas/awoc/pulls)

---

Thank you for contributing to AWOC! Together, we're building the future of AI-assisted development. 🚀