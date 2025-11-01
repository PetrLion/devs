#!/bin/bash
# Setup script to create dev, stage, and main branches

set -e

echo "========================================="
echo "Setting up DevSecOps repository branches"
echo "========================================="
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not a git repository"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"
echo ""

# Function to create and push branch
create_branch() {
    local branch_name=$1
    
    echo "🔧 Creating branch: $branch_name"
    
    # Check if branch already exists locally
    if git show-ref --verify --quiet refs/heads/$branch_name; then
        echo "   ℹ️  Branch $branch_name already exists locally"
    else
        git checkout -b $branch_name
        echo "   ✅ Created local branch: $branch_name"
    fi
    
    # Push to remote
    if git ls-remote --heads origin $branch_name | grep -q $branch_name; then
        echo "   ℹ️  Branch $branch_name already exists on remote"
    else
        git push -u origin $branch_name
        echo "   ✅ Pushed branch to remote: $branch_name"
    fi
    
    echo ""
}

# Create main branch if it doesn't exist
if ! git show-ref --verify --quiet refs/heads/main; then
    echo "🔧 Creating main branch"
    git checkout -b main
    git push -u origin main
    echo "   ✅ Created and pushed main branch"
    echo ""
fi

# Switch to main as base
git checkout main 2>/dev/null || git checkout -b main

# Create dev branch
create_branch "dev"

# Create stage branch
create_branch "stage"

# Return to original branch or main
if [ "$CURRENT_BRANCH" != "" ] && git show-ref --verify --quiet refs/heads/$CURRENT_BRANCH; then
    git checkout $CURRENT_BRANCH
    echo "📍 Returned to branch: $CURRENT_BRANCH"
else
    git checkout main
    echo "📍 Switched to branch: main"
fi

echo ""
echo "========================================="
echo "✅ Branch setup complete!"
echo "========================================="
echo ""
echo "Available branches:"
git branch -a | grep -E '(main|dev|stage)'
echo ""
echo "Next steps:"
echo "1. Configure branch protection for 'main' (see SETUP.md)"
echo "2. Add collaborators"
echo "3. Create tag v1.0.0 to trigger first release"
