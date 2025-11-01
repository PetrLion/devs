# Contributing Guide

## Development Workflow

### 1. Working on Features

All development should happen in the `dev` branch or feature branches from `dev`:

```bash
# Start from dev
git checkout dev
git pull origin dev

# Create feature branch
git checkout -b feature/my-new-feature

# Make changes and commit
git add .
git commit -m "feat: add new feature"

# Push feature branch
git push origin feature/my-new-feature

# Create PR to dev branch
```

### 2. Promotion to Staging

Once features are ready for testing:

```bash
# Create PR from dev to stage
# After review and approval, merge
```

### 3. Release to Production

When staging is stable and ready:

```bash
# Create PR from stage to main
# After review and approval, merge

# Then create release tag
git checkout main
git pull origin main
git tag v1.0.0
git push origin v1.0.0
```

## Branch Strategy

```
feature/* → dev → stage → main → release (tag v*)
```

- **feature/** - Individual features (temporary)
- **dev** - Active development
- **stage** - Pre-production testing
- **main** - Production ready code (protected)

## Automated Checks

### Every Push to dev/stage/main

These workflows run automatically:

1. **Build** - Creates zip artifact from source
2. **SBOM** - Generates Software Bill of Materials
3. **Cosign Sign** - Signs artifacts with keyless signature
4. **Scorecard** - OpenSSF security scoring
5. **Grype** - Vulnerability scanning

### On Pull Request to main

All checks must pass before merge is allowed.

### On Tag (v*)

Creates GitHub Release with:
- Build artifacts
- SBOM
- Cosign signatures
- Security reports

## Local Development

### Setup

```bash
# Install dependencies
pip install -r devsec1-main/requirements.txt

# Build locally
cd devsec1-main
make build

# Check output
ls -lh dist/
```

### Testing Changes

Before pushing:

```bash
# Ensure code is formatted
# Run any local tests if they exist
# Build to verify no errors
cd devsec1-main
make clean && make build
```

## Pull Request Guidelines

### PR Title Format

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `chore:` - Maintenance tasks
- `security:` - Security improvements

### PR Description

Include:
- What changed
- Why the change was needed
- Any relevant issue numbers
- Testing performed

### PR Checklist

- [ ] Code builds successfully
- [ ] No new security vulnerabilities introduced
- [ ] Documentation updated if needed
- [ ] Follows existing code style
- [ ] All CI checks pass

## Security

### Vulnerability Scanning

- Grype scans run on every push
- Critical vulnerabilities will fail the build
- Review and fix security issues before merging

### Cosign Signatures

- Artifacts are automatically signed using keyless OIDC
- Signatures verify the authenticity of releases
- No manual key management required

### OpenSSF Scorecard

- Runs daily at 6:00 UTC
- Evaluates repository security practices
- Results published to Security tab

## Troubleshooting

### Build Failures

Check the Actions tab for detailed logs:

```bash
# Common issues:
# 1. Missing dependencies - check requirements.txt
# 2. Syntax errors - review your code
# 3. Build artifacts missing - verify Makefile
```

### Failed Security Checks

If Grype fails:

1. Review the vulnerability report
2. Update affected dependencies if possible
3. Document any accepted risks
4. Consider if vulnerability affects your use case

### Workflow Not Triggering

Ensure:

- Commits are pushed to correct branch (dev/stage/main)
- `.github/workflows/` files are present in the branch
- Repository Actions are enabled

## Getting Help

- Review workflow files in `.github/workflows/`
- Check branch setup guide in `.github/SETUP_BRANCHES.md`
- Review branch strategy in `.github/BRANCH_STRATEGY.md`
- Ask maintainers for assistance

## Code of Conduct

- Be respectful and constructive
- Focus on the code, not the person
- Help others learn and grow
- Follow security best practices
- Document your changes clearly
