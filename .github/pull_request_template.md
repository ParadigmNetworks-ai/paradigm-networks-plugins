<!-- PRTEMPLATE:START v1 -->
# CHANGELOG

> **ℹ️ NEW: Automated CHANGELOG Updates**
> For **feature branches → develop**: You no longer need to manually update CHANGELOG.md!
> Just check the box(es) that apply to your changes and write your entries directly on the checkbox line.
> The changelog will be updated automatically when your PR merges.
> **No more merge conflicts** when multiple PRs are open simultaneously.

> **📝 How to Use This Template:**
> 1. Check the box(es) that apply to your changes below
> 2. Write your ticket and description directly on the checkbox line after the category
> 3. Format: `- [x] **Category** - [PN-####] - Your description here`
> 4. You can add multiple lines for the same category if needed
> 5. Use `[NOCHANGELOG]` in PR title if no changelog update is needed

**NOTE** Remove this checklist for PRs to branches other than `develop`.

**MANDATORY: Check the box and add your changes below**

<!-- Added - New features or capabilities -->
- [ ] **Added**

<!-- Changed - Changes to existing functionality -->
- [ ] **Changed**

<!-- Fixed - Bug fixes -->
- [ ] **Fixed**

<!-- Removed - Removed features or deprecated functionality -->
- [ ] **Removed**

<!-- Requirements - Dependency updates or requirement changes -->
- [ ] **Requirements**

<!-- Security - Security improvements or vulnerability fixes -->
- [ ] **Security**

---

# PR Checklist

## Automated Validations (CI/CD Jobs)
> **⚠️ These checkboxes are automatically managed by CI/CD workflows**
> - They will be checked ✅ when scans pass
> - They will be unchecked ❌ if scans fail
> - **Do NOT manually check these boxes** - they update based on actual scan results

- [ ] **Security Scan** – Trivy vulnerability scan (auto-updated after scan completes)
- [ ] **Code Quality** – Semgrep static analysis (auto-updated after scan completes)
- [ ] **Build Pipeline** – All CI jobs (auto-updated after builds complete)

---

## Manual Reviews – Core Requirements (Required for all PRs)
- [ ] **CHANGELOG Categories** Checked above ↑ (or use `[NOCHANGELOG]` if not applicable)
- [ ] **Jira ID** in title `[PN-####]` (validated automatically)
- [ ] **No Commented-out Code** Check
- [ ] **UnitTest** Check
- [ ] **Code Dependency** Check

---

## Conditional Requirements (Check if applicable)
- [ ] **Protocol Dependency** Check
- [ ] **API Gateway** Check
- [ ] **Database Changes** – Migration scripts tested & reviewed
- [ ] **Environment Variables** – Documented & added to environments

---

## Communication
- [ ] **Loom** Check
<!-- PRTEMPLATE:END -->
