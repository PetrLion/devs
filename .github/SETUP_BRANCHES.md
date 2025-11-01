# Setting Up Three-Branch Structure

## Initial Branch Setup

After merging this PR, the repository needs to be configured with three main branches: `dev`, `stage`, and `main`.

### Step 1: Create Main Branch (if not exists)

If `main` doesn't exist as the default branch:

```bash
git checkout copilot/build-artifact-collection
git branch -M main
git push -u origin main
```

Then in GitHub Settings → General → Default branch, set `main` as default.

### Step 2: Create Dev Branch

```bash
git checkout main
git checkout -b dev
git push -u origin dev
```

### Step 3: Create Stage Branch

```bash
git checkout main
git checkout -b stage
git push -u origin stage
```

### Step 4: Configure Branch Protection for Main

In GitHub Repository Settings → Branches → Add branch protection rule:

**Branch name pattern**: `main`

**Protection rules**:
- ✅ **Require a pull request before merging**
  - Require approvals: 1
  - Dismiss stale pull request approvals when new commits are pushed
  
- ✅ **Require status checks to pass before merging**
  - Require branches to be up to date before merging
  - Status checks that are required:
    - `build` (from build-and-release.yml)
    - `sbom` (from build-and-release.yml)
    - `cosign-sign` (from build-and-release.yml)
    - `scorecard` (from security-checks.yml)
    - `grype` (from security-checks.yml)

- ✅ **Require conversation resolution before merging**

- ✅ **Restrict who can push to matching branches**
  - Enable this to ensure all changes go through PR process
  - Optionally add specific users/teams who can override (admins only)

- ⚠️ **Do not allow bypassing the above settings**
  - Recommended for strict enforcement

### Step 5: Optional Protection for Stage

You may also want to add protection rules for `stage`:

**Branch name pattern**: `stage`

- ✅ Require a pull request before merging
- ✅ Require status checks to pass

### Step 6: Verify Workflows

After branches are created, verify workflows run correctly:

1. Make a small change in `dev` branch and push
2. Check that workflows trigger and pass
3. Create PR from `dev` to `stage`
4. Create PR from `stage` to `main`
5. After merge to `main`, create a tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
6. Verify that Release workflow creates a GitHub Release

## Testing the Pipeline

### Test Build Pipeline

```bash
git checkout dev
echo "# Test change" >> test.txt
git add test.txt
git commit -m "Test: verify build pipeline"
git push origin dev
```

Check Actions tab to see if workflows run.

### Test Release Creation

```bash
git checkout main
git tag v1.0.0
git push origin v1.0.0
```

Check:
1. Workflows run successfully
2. Release is created with all artifacts:
   - build artifacts (*.zip)
   - SBOM (sbom.json)
   - Cosign signatures (*.sig)
   - Cosign certificates (*.crt)

## Workflow Behavior by Branch

| Workflow | dev | stage | main | tag v* |
|----------|-----|-------|------|--------|
| Build | ✅ | ✅ | ✅ | ✅ |
| SBOM | ✅ | ✅ | ✅ | ✅ |
| Cosign Sign | ✅ | ✅ | ✅ | ✅ |
| Release | ❌ | ❌ | ❌ | ✅ |
| Scorecard | ✅ | ✅ | ✅ | ❌ |
| Grype | ✅ | ✅ | ✅ | ❌ |

## Expected Development Flow

```
Developer → dev branch (commit & push)
              ↓ (workflows run)
         dev → stage (PR & merge)
              ↓ (workflows run)
        stage → main (PR & merge)
              ↓ (workflows run)
         main → tag v* (create release)
              ↓ (release workflow runs)
         GitHub Release created
```

## Troubleshooting

### If workflows don't trigger:
1. Check that `.github/workflows/` files are in the branch
2. Verify branch names match exactly in workflow triggers
3. Check repository settings → Actions → General → Actions permissions

### If Cosign signing fails:
1. Ensure repository has `id-token: write` permission
2. Verify the workflow runs on GitHub (not locally)
3. Check GitHub Actions secrets if using stored keys

### If Release doesn't create:
1. Verify tag starts with `v` (e.g., `v1.0.0`)
2. Check that all prerequisite jobs passed
3. Verify repository has `contents: write` permission

## Next Steps

After completing this setup:
1. Add collaborators to repository
2. Assign roles (who can approve PRs, who can merge to main)
3. Document team workflow in team wiki/docs
4. Set up notifications for security alerts
5. Review OpenSSF Scorecard results and improve score
