# Branch Strategy for DevSecOps Pipeline

## Three-Branch Model

This repository uses a three-branch strategy for proper DevSecOps workflow:

### 1. `dev` (Development Branch)
- **Purpose**: Active development and feature integration
- **Workflow**: Developers create feature branches and merge into `dev`
- **CI/CD**: All workflows run on push to `dev`
- **Security**: Scorecard and Grype scans run automatically

### 2. `stage` (Staging Branch)  
- **Purpose**: Pre-production testing and validation
- **Workflow**: Stable `dev` code is merged into `stage` for testing
- **CI/CD**: All workflows run on push to `stage`
- **Security**: Full security checks before production

### 3. `main` (Production Branch)
- **Purpose**: Production-ready code only
- **Workflow**: Only accepts Pull Requests (no direct pushes)
- **Protection**: Branch protection rules enforce:
  - Require pull request reviews
  - Require status checks to pass
  - No direct pushes (except admins in emergencies)
- **Releases**: Git tags on `main` trigger release workflow

## Workflow Triggers

### Build and Release (`build-and-release.yml`)
- Runs on push to: `dev`, `stage`, `main`
- Runs on pull requests to: `main`
- Runs on tags: `v*` (creates GitHub Release)

### Security Checks (`security-checks.yml`)
- Runs on push to: `dev`, `stage`, `main`
- Runs on pull requests to: `main`
- Runs on schedule: Daily at 6:00 UTC

## Release Process

1. Develop features in `dev` branch
2. Test in `stage` branch
3. Create Pull Request from `stage` to `main`
4. After merge, create a tag: `git tag v1.0.0`
5. Push tag: `git push origin v1.0.0`
6. GitHub Actions will:
   - Build artifacts
   - Generate SBOM with Syft
   - Sign with Cosign (keyless OIDC)
   - Create GitHub Release with all artifacts

## Branch Protection Setup

For `main` branch, configure in GitHub Settings → Branches:
- ✅ Require a pull request before merging
- ✅ Require approvals: 1
- ✅ Require status checks to pass before merging:
  - `build`
  - `sbom`
  - `cosign-sign`
  - `scorecard`
  - `grype`
- ✅ Require conversation resolution before merging
- ✅ Do not allow bypassing the above settings (recommended)
- ✅ Restrict who can push to matching branches (only admins)
