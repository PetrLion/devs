# GitHub Setup Instructions

## 1. Create Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `devsecops-demo` (or your choice)
3. Description: "DevSecOps demonstration project with SBOM, Cosign signing, and security scanning"
4. Choose **Private** or **Public** (Private recommended for academic work)
5. **Do NOT** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

## 2. Connect Local Repository to GitHub

```powershell
# Add the remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin git@github.com:YOUR_USERNAME/devsecops-demo.git

# Push all branches to GitHub
git push -u origin main
git push -u origin dev
git push -u origin stage
```

**Alternative if SSH fails, use HTTPS:**
```powershell
git remote add origin https://github.com/YOUR_USERNAME/devsecops-demo.git
```

## 3. Add Collaborators and Set Permissions

### Add 4 Users
1. Go to repository Settings → Collaborators and teams
2. Click "Add people" or "Invite a collaborator"
3. Add 4 users total (including yourself)
   - You will need their GitHub usernames
   - They will receive email invitations

### Set Branch Protection for `main`
1. Go to Settings → Branches
2. Click "Add branch protection rule"
3. Branch name pattern: `main`
4. Enable:
   - ✅ "Require a pull request before merging"
   - ✅ "Require status checks to pass before merging"
   - ✅ "Require branches to be up to date before merging"
   - Under "Restrict who can push to matching branches": **Check this** and only select 1 user
   - (Optional but recommended) "Require conversation resolution before merging"
   - (Optional) "Do not allow bypassing the above settings"
5. Click "Create"

### Set CODEOWNERS
Edit `.github/CODEOWNERS` and add your actual GitHub username or team:

```
# Require review from this user
* @YOUR_GITHUB_USERNAME
```

## 4. Configure SSH Key for GitHub (if not done already)

1. Display your public key:
```powershell
Get-Content $env:USERPROFILE\.ssh\id_rsa_github.pub
```

2. Copy the entire output

3. Go to GitHub → Settings → SSH and GPG keys → New SSH key
4. Title: "Windows DevSecOps Demo"
5. Key type: Authentication Key
6. Paste your public key
7. Click "Add SSH key"

4. Test connection:
```powershell
ssh -T git@github.com
# Type "yes" if prompted, should see: "Hi USERNAME! You've successfully authenticated..."
```

## 5. Create Release v1.0.0

Once all branches are pushed and workflows are set up:

```powershell
# Make sure you're on main branch
git checkout main

# Create and push the tag to trigger release workflow
git tag v1.0.0
git push origin v1.0.0
```

The GitHub Actions workflow will automatically:
- Build the artifact
- Generate SBOM
- Sign with Cosign (keyless)
- Create GitHub Release v1.0.0 with all artifacts

## 6. Verify Security Checks

### Check Scorecard Results
- Go to repository → Actions tab → "OpenSSF Scorecard" workflow
- Click on latest run → Download "results.sarif" artifact
- Or view in repository → Security → Code scanning alerts

### Check Grype Results  
- Go to repository → Actions tab → "Grype SBOM Scan" workflow
- View the scan output in the job logs

## 7. Fix Any Issues

If Scorecard or Grype find issues:
1. Create a new branch from `dev`: `git checkout -b fix/security-issue`
2. Make fixes
3. Commit: `git add .; git commit -m "Fix: description"`
4. Push: `git push origin fix/security-issue`
5. Create Pull Request: `fix/security-issue` → `dev`
6. After merge to dev, merge dev → stage → main via PRs

## Common Issues

### "Permission denied (publickey)"
- Make sure SSH key is added to GitHub
- Test: `ssh -T git@github.com`
- If still fails, use HTTPS with Personal Access Token

### "Branch protection rule requires status checks"
- Wait for workflows to complete
- Check Actions tab for failed workflows
- Fix any issues and push again

### "Cosign signing failed"
- The workflow uses keyless signing, should work automatically
- If it fails, check Actions logs for details
- May need to ensure repository has write permissions for releases

### "Makefile build failed"
- Ensure `src/` directory exists with `41_scan_stream_default.py`
- The workflow installs `zip` automatically on Ubuntu
- Check Actions logs for specific error

## Quick Reference

```powershell
# List all branches
git branch -a

# Switch branches
git checkout dev
git checkout stage  
git checkout main

# Create and push new feature branch
git checkout -b feature/my-feature
# ... make changes ...
git add .
git commit -m "Add feature X"
git push origin feature/my-feature
# Create PR on GitHub

# View repository status
git status
git log --oneline

# View remote
git remote -v

# Update from remote
git fetch origin
git pull origin main
```

