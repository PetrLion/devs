# DevSecOps Workflow Diagram

## Complete Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DEVELOPMENT FLOW                            │
└─────────────────────────────────────────────────────────────────────┘

   Developer
      │
      │ commits code
      ▼
 ┌─────────┐
 │   dev   │ ◄── feature branches merge here
 └────┬────┘
      │
      │ Triggers on push:
      │ • Build (make build → zip artifact)
      │ • SBOM Generation (Syft → sbom.json)
      │ • Cosign Sign (keyless OIDC → .sig, .crt)
      │ • Scorecard (security score)
      │ • Grype (vulnerability scan)
      │
      │ PR + Review
      ▼
 ┌─────────┐
 │  stage  │ ◄── testing environment
 └────┬────┘
      │
      │ Triggers on push:
      │ • All same checks as dev
      │ • Integration testing
      │
      │ PR + Review + Approval
      ▼
 ┌─────────┐
 │  main   │ ◄── production (protected)
 └────┬────┘
      │
      │ Protected by:
      │ • Required PR reviews
      │ • Status checks must pass
      │ • No direct pushes
      │
      │ Create tag (v*)
      ▼
 ┌─────────┐
 │ Release │ ◄── GitHub Release created
 └─────────┘
      │
      │ Contains:
      │ • scan-app-*.zip (signed artifact)
      │ • sbom.json (SBOM)
      │ • *.sig (Cosign signature)
      │ • *.crt (Cosign certificate)
      │
      ▼
   Published Release


┌─────────────────────────────────────────────────────────────────────┐
│                    BUILD & RELEASE WORKFLOW                         │
│              (.github/workflows/build-and-release.yml)              │
└─────────────────────────────────────────────────────────────────────┘

┌──────────┐
│  Trigger │  push: [dev, stage, main], tags: v*, PR: main
└────┬─────┘
     │
     ▼
┌────────────────┐
│  Job: Build    │  
│                │  • Checkout code
│                │  • Setup Python 3.11
│                │  • Install dependencies (requirements.txt)
│                │  • Run: make build
│                │  • Upload artifact: build-artifacts/
└────┬───────────┘
     │
     ▼
┌────────────────┐
│  Job: SBOM     │  needs: build
│                │  
│                │  • Download build-artifacts
│                │  • Generate SBOM with Syft (CycloneDX JSON)
│                │  • Upload artifact: sbom.json
└────┬───────────┘
     │
     ▼
┌────────────────────┐
│  Job: Cosign Sign  │  needs: [build, sbom]
│                    │  permissions: id-token: write
│                    │  
│                    │  • Download build-artifacts & sbom
│                    │  • Install Cosign v2.2.0
│                    │  • Sign artifacts (keyless OIDC)
│                    │  • Create .sig and .crt files
│                    │  • Upload cosign-signatures/
└────┬───────────────┘
     │
     │ Only if: startsWith(github.ref, 'refs/tags/v')
     ▼
┌────────────────┐
│  Job: Release  │  needs: [build, sbom, cosign-sign]
│                │  permissions: contents: write
│                │  
│                │  • Download all artifacts
│                │  • Create GitHub Release
│                │  • Attach all artifacts to release
│                │  • Generate release notes
└────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                    SECURITY CHECKS WORKFLOW                         │
│              (.github/workflows/security-checks.yml)                │
└─────────────────────────────────────────────────────────────────────┘

┌──────────┐
│  Trigger │  push: [dev, stage, main], PR: main, schedule: daily
└────┬─────┘
     │
     ├─────────────┬─────────────┬─────────────┐
     │             │             │             │
     ▼             ▼             ▼             ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Scorecard│  │   SBOM   │  │  Grype   │
│          │  │          │  │          │
│ OpenSSF  │  │  Syft    │  │ Vuln     │
│ Security │  │ Generate │  │ Scanner  │
│ Score    │  │ SBOM     │  │          │
│          │  │          │  │ needs:   │
│ Upload   │  │ Upload   │  │ sbom     │
│ SARIF    │  │ artifact │  │          │
│          │  │          │  │ Upload   │
│          │  │          │  │ SARIF    │
└──────────┘  └──────────┘  └──────────┘
     │             │             │
     └─────────────┴─────────────┘
                   │
                   ▼
          Security Tab Updated
          (Code scanning alerts)


┌─────────────────────────────────────────────────────────────────────┐
│                      ARTIFACT FLOW                                  │
└─────────────────────────────────────────────────────────────────────┘

Source Code (src/)
      │
      │ make build
      ▼
scan-app-VERSION.zip ──────────┐
      │                        │
      │                        │
      ▼                        ▼
   Syft scan              Cosign sign
      │                        │
      ▼                        │
   sbom.json ──────────────────┤
                                │
                                ▼
                        GitHub Release
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
            Downloadable Files      Release Assets:
            • scan-app-*.zip        • Build artifact
            • sbom.json             • SBOM
            • *.sig                 • Signatures
            • *.crt                 • Certificates


┌─────────────────────────────────────────────────────────────────────┐
│                    SECURITY FEATURES                                │
└─────────────────────────────────────────────────────────────────────┘

1. OpenSSF Scorecard
   ├─ Checks: Branch protection, Code review, Dependency updates
   ├─ Output: SARIF file → Security tab
   └─ Score: 0-10 rating

2. Grype Vulnerability Scanning
   ├─ Scans: SBOM for known CVEs
   ├─ Severity: critical, high, medium, low
   ├─ Action: fail-build on critical (configurable)
   └─ Output: SARIF file → Security tab

3. Cosign Keyless Signing
   ├─ Method: OIDC (GitHub token)
   ├─ No keys to manage/store
   ├─ Creates: .sig (signature) + .crt (certificate)
   └─ Verifiable: cosign verify-blob

4. SBOM (Software Bill of Materials)
   ├─ Tool: Syft (Anchore)
   ├─ Format: CycloneDX JSON
   ├─ Contains: All dependencies
   └─ Use: Supply chain security, license compliance


┌─────────────────────────────────────────────────────────────────────┐
│                   BRANCH PROTECTION RULES                           │
└─────────────────────────────────────────────────────────────────────┘

main branch (production):
  ✅ Require pull request before merging
  ✅ Require 1 approval
  ✅ Dismiss stale approvals
  ✅ Require status checks:
     • build
     • sbom
     • cosign-sign
     • scorecard
     • grype
  ✅ Require conversation resolution
  ✅ Restrict push (admins only)
  ✅ Do not allow bypass

stage branch (optional):
  ✅ Require pull request
  ✅ Require 1 approval
  ✅ Require status checks

dev branch:
  ⚪ No restrictions
  ⚪ Direct pushes allowed
  ⚪ Feature branches merge here


┌─────────────────────────────────────────────────────────────────────┐
│                    TYPICAL WORKFLOW                                 │
└─────────────────────────────────────────────────────────────────────┘

Day 1: Feature Development
  1. git checkout dev
  2. git checkout -b feature/new-feature
  3. # make changes
  4. git push origin feature/new-feature
  5. Create PR: feature/new-feature → dev
  6. Review + Merge
  7. Actions run on dev (build, security checks)

Day 2-3: Testing in Stage
  1. Create PR: dev → stage
  2. Review + Merge
  3. Actions run on stage
  4. QA team tests in staging environment

Day 4: Production Release
  1. Create PR: stage → main
  2. Review + Approval
  3. Merge to main
  4. Actions run on main
  5. git tag v1.0.0
  6. git push origin v1.0.0
  7. Release workflow creates GitHub Release
  8. Artifacts published with signatures


┌─────────────────────────────────────────────────────────────────────┐
│                    VERIFICATION COMMANDS                            │
└─────────────────────────────────────────────────────────────────────┘

# Verify Cosign signature
cosign verify-blob \
  --signature scan-app-1.0.0.zip.sig \
  --certificate scan-app-1.0.0.zip.crt \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  scan-app-1.0.0.zip

# View SBOM
cat sbom.json | jq '.components[] | {name: .name, version: .version}'

# Check for vulnerabilities in SBOM
grype sbom:./sbom.json

# Build locally
cd devsec1-main
make build
```

## Key Benefits

✅ **Automated Security**: Every commit is scanned
✅ **Supply Chain Security**: SBOM tracks all dependencies
✅ **Artifact Integrity**: Cosign signatures prove authenticity
✅ **Compliance**: Audit trail for all changes
✅ **Quality Gates**: Code must pass checks before production
✅ **Transparency**: All scans visible in Security tab
