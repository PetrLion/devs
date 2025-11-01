# Verification Checklist

## Post-Merge Setup Tasks

After this PR is merged, complete these steps to finalize the DevSecOps pipeline:

### 1. Branch Creation

- [ ] Create `main` branch (if not exists)
  ```bash
  git checkout copilot/build-artifact-collection
  git branch -M main
  git push -u origin main
  ```

- [ ] Set `main` as default branch in GitHub Settings

- [ ] Create `dev` branch from `main`
  ```bash
  git checkout main
  git checkout -b dev
  git push -u origin dev
  ```

- [ ] Create `stage` branch from `main`
  ```bash
  git checkout main
  git checkout -b stage
  git push -u origin stage
  ```

### 2. Branch Protection (main)

In GitHub Settings → Branches → Add rule for `main`:

- [ ] Require a pull request before merging
  - [ ] Require approvals: 1
  - [ ] Dismiss stale pull request approvals when new commits are pushed

- [ ] Require status checks to pass before merging
  - [ ] Require branches to be up to date before merging
  - [ ] Required checks:
    - [ ] `build`
    - [ ] `sbom`
    - [ ] `cosign-sign`
    - [ ] `scorecard`
    - [ ] `grype`

- [ ] Require conversation resolution before merging

- [ ] Restrict who can push to matching branches
  - [ ] Add admin users only

- [ ] Do not allow bypassing the above settings (recommended)

### 3. Optional: Branch Protection (stage)

In GitHub Settings → Branches → Add rule for `stage`:

- [ ] Require a pull request before merging
- [ ] Require approvals: 1
- [ ] Require status checks to pass

### 4. Repository Permissions

Settings → Collaborators and teams:

- [ ] Add collaborators (developers)
- [ ] Assign roles:
  - [ ] Admin: 1-2 people (can merge to main)
  - [ ] Write: Developers (can push to dev/stage)
  - [ ] Read: Reviewers (can review PRs)

### 5. Actions Configuration

Settings → Actions → General:

- [ ] Actions permissions: "Allow all actions and reusable workflows"
- [ ] Workflow permissions: "Read and write permissions"
- [ ] Allow GitHub Actions to create and approve pull requests: Enabled

### 6. Security Settings

Settings → Code security and analysis:

- [ ] Enable Dependabot alerts
- [ ] Enable Dependabot security updates
- [ ] Enable Dependency graph
- [ ] Enable Secret scanning
- [ ] Enable Push protection (prevents committing secrets)

### 7. Initial Workflow Test

Test that workflows run on each branch:

#### Test on dev:
```bash
git checkout dev
echo "# Test" >> test.txt
git add test.txt
git commit -m "test: verify dev workflow"
git push origin dev
```
- [ ] Check Actions tab - workflows should run
- [ ] Verify build, SBOM, Cosign, Scorecard, Grype all complete

#### Test on stage:
```bash
git checkout stage
git merge dev
git push origin stage
```
- [ ] Check Actions tab - workflows should run

#### Test on main via PR:
- [ ] Create PR from stage to main
- [ ] Verify required checks run
- [ ] Verify checks must pass before merge allowed
- [ ] Merge PR
- [ ] Verify workflows run on main

### 8. Test Release Creation

Create first release:

```bash
git checkout main
git pull origin main
git tag v1.0.0
git push origin v1.0.0
```

- [ ] Verify release workflow triggers
- [ ] Check that GitHub Release is created
- [ ] Verify Release contains:
  - [ ] Build artifact (scan-app-*.zip)
  - [ ] SBOM (sbom.json)
  - [ ] Cosign signatures (*.sig)
  - [ ] Cosign certificates (*.crt)

### 9. Verify Security Features

- [ ] Check Security tab for Scorecard results
- [ ] Review Dependabot alerts (if any)
- [ ] Verify Grype scan results
- [ ] Check that SARIF uploads appear in Code scanning alerts

### 10. Documentation

- [ ] Update README with actual badge status
- [ ] Add team-specific workflow documentation
- [ ] Document any environment-specific configurations
- [ ] Create team wiki/guide if needed

### 11. Notifications (Optional)

Set up notifications for:

- [ ] Failed workflows (Slack/email)
- [ ] Security alerts (Dependabot/Grype)
- [ ] New releases
- [ ] PR reviews needed

### 12. Continuous Monitoring

Regular tasks:

- [ ] Weekly: Review OpenSSF Scorecard score and improve
- [ ] Weekly: Check for new Dependabot alerts
- [ ] Monthly: Review and update dependencies
- [ ] Monthly: Test disaster recovery (can rebuild from scratch)

## Troubleshooting

### If workflows don't appear:

1. Ensure `.github/workflows/` exists in branch
2. Check Actions → General → Actions permissions
3. Verify YAML syntax is valid

### If Cosign signing fails:

1. Verify workflow has `id-token: write` permission
2. Ensure running on GitHub (not locally)
3. Check that job `needs: [build, sbom]` dependencies passed

### If Release doesn't create:

1. Verify tag starts with `v` (e.g., v1.0.0)
2. Check that all jobs in workflow passed
3. Ensure `contents: write` permission exists

### If status checks don't appear in PR:

1. Push a commit after creating PR to trigger checks
2. Verify workflow triggers include `pull_request` for `main`
3. Check that status check names match exactly in branch protection

## Success Criteria

✅ All branches (dev, stage, main) exist
✅ Branch protection rules configured for main
✅ Workflows trigger on push to dev/stage/main
✅ All security checks pass
✅ Release creation works with tags
✅ Team can follow documented workflow
✅ Security features are enabled and monitored

## Next Steps After Verification

1. Train team on new workflow
2. Migrate existing work to new branch structure
3. Start using PR-based workflow
4. Monitor and iterate on process
5. Celebrate successful DevSecOps implementation! 🎉
