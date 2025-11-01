# Next Steps to Complete the DevSecOps Assignment

## ✅ Completed Steps

1. ✅ Created repository structure with README.md, Makefile, workflows
2. ✅ Downloaded 41_scan_stream_default.py from savostyanenko repository
3. ✅ Created requirements.txt with dependencies (opencv-python, PyMySQL, requests)
4. ✅ Generated SSH key pair (id_rsa_github, id_rsa_github.pub)
5. ✅ Installed Git 2.51.2 via winget
6. ✅ Initialized local Git repository
7. ✅ Created branches: main, dev, stage
8. ✅ Configured Git user (kutsiukd@gmail.com)
9. ✅ Fixed Cosign signing workflow (using --oidc-provider=github)
10. ✅ Fixed Grype workflow exit code
11. ✅ Created SETUP_INSTRUCTIONS.md
12. ✅ Committed all files locally

## 🎯 Remaining Steps (Do These on GitHub)

### Step 1: Create GitHub Repository
1. Go to https://github.com/new
2. Repository name: `devsecops-demo` (or your choice)
3. Description: "DevSecOps demonstration project with SBOM, Cosign signing, and security scanning"
4. Choose **Private**
5. **DO NOT** initialize with README, .gitignore, or license
6. Click "Create repository"

### Step 2: Push Local Repository to GitHub

Run these commands in PowerShell (replace YOUR_USERNAME):

```powershell
# If SSH works:
git remote add origin git@github.com:YOUR_USERNAME/devsecops-demo.git

# OR if SSH doesn't work, use HTTPS (will need GitHub token):
git remote add origin https://github.com/YOUR_USERNAME/devsecops-demo.git

# Push all branches
git push -u origin main
git push -u origin dev
git push -u origin stage
```

**If you get "Permission denied (publickey)":**
1. Copy your public key: `Get-Content $env:USERPROFILE\.ssh\id_rsa_github.pub`
2. Go to GitHub → Settings → SSH and GPG keys → New SSH key
3. Paste the key and save
4. Try `git push` again

**If using HTTPS:**
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with `repo` scope
3. Use the token as password when pushing

### Step 3: Add 4 Collaborators

1. Go to your GitHub repository Settings → Collaborators and teams
2. Click "Add people" or "Invite a collaborator"
3. Add 4 users total (including yourself)
4. Each will receive an email invitation

**Note:** You need to know the GitHub usernames of your 3 teammates

### Step 4: Configure Branch Protection for `main`

1. Go to Settings → Branches
2. Click "Add branch protection rule"
3. Branch name pattern: `main`
4. Enable these settings:
   - ✅ Require a pull request before merging
   - ✅ Require status checks to pass before merging
     - Add checks: `build-release`, `scorecard-analysis`, `Grype SBOM Scan`
   - ✅ Require branches to be up to date before merging
   - ✅ Restrict who can push to matching branches (only select 1 user)
   - ✅ Require conversation resolution before merging
5. Click "Create"

### Step 5: Update CODEOWNERS

Edit `.github/CODEOWNERS` on GitHub (or locally and push):
1. Replace `@YOUR_GITHUB_USERNAME` with your actual GitHub username
2. Commit and push

### Step 6: Create Release v1.0.0

```powershell
# Make sure you're on main branch
git checkout main

# Create and push tag v1.0.0
git tag v1.0.0
git push origin v1.0.0
```

This will automatically trigger the GitHub Actions workflow that:
- Builds the artifact (scan-app-1.0.0.zip)
- Generates SBOM (sbom.spdx.json)
- Signs with Cosign (keyless)
- Creates GitHub Release v1.0.0

### Step 7: Check Security Scan Results

1. Go to repository → Actions tab
2. Check workflows:
   - **OpenSSF Scorecard**: Should run automatically
   - **Grype SBOM Scan**: Should run on push
   - **Build, Sign, and Release**: Should run when you push tag v1.0.0

3. Download and review:
   - Scorecard results (results.sarif)
   - Grype scan output
   - SBOM artifact

### Step 8: Fix Any Security Issues Found

If Scorecard or Grype find issues:
1. Create a new branch: `git checkout -b fix/security-issues`
2. Make fixes
3. Commit: `git add . ; git commit -m "Fix security issues"`
4. Push: `git push origin fix/security-issues`
5. Create Pull Request on GitHub: `fix/security-issues` → `dev`
6. After approval, merge via PR

## 📋 Checklist

- [ ] GitHub repository created
- [ ] Local code pushed to GitHub (all 3 branches)
- [ ] SSH key added to GitHub OR HTTPS token configured
- [ ] 4 collaborators added
- [ ] Branch protection configured for main
- [ ] CODEOWNERS updated with your GitHub username
- [ ] Release v1.0.0 created and workflows ran successfully
- [ ] Scorecard results checked
- [ ] Grype results checked
- [ ] Any security issues fixed
- [ ] All documentation files updated (steps.txt, README.md)

## 🐛 Common Issues & Solutions

### Issue: "git push" fails with permission denied
**Solution:** 
- SSH: Add public key to GitHub
- HTTPS: Use Personal Access Token

### Issue: Workflows not running
**Solution:** 
- Check repository Settings → Actions → General
- Ensure workflows have permission to run
- Check Actions tab for error messages

### Issue: Cosign signing fails
**Solution:**
- Should work automatically with keyless signing
- Check Actions logs for specific error
- Ensure permissions include `id-token: write`

### Issue: Makefile build fails
**Solution:**
- Ensure `src/` directory exists with `41_scan_stream_default.py`
- Ubuntu runners have `zip` installed by default
- Check Actions logs for specific error

### Issue: Branch protection prevents push
**Solution:**
- This is intentional! Use Pull Requests to merge into main
- Push to dev or stage, then create PR to main

## 📚 Additional Resources

- Planning Poker: https://planningpokeronline.com/
- GitHub Actions Docs: https://docs.github.com/en/actions
- Cosign Docs: https://docs.sigstore.dev/cosign/
- OpenSSF Scorecard: https://github.com/ossf/scorecard
- Grype Docs: https://github.com/anchore/grype

## 📝 Notes

- The code in `src/41_scan_stream_default.py` contains intentional security vulnerabilities for demonstration
- All workflows run on Ubuntu Linux runners
- The artifact is a zip file of the source code (pseudo-binary)
- SBOM is generated in SPDX format
- Cosign uses keyless signing with GitHub OIDC

Good luck! 🚀

