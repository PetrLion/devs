Access and Branch Protection

Users
- Додайте 4-х користувачів у Settings → Collaborators & teams.
- Лише одному користувачу дозволяйте push у `main` або увімкніть повну заборону прямого push.

Branch protection (Settings → Branches → Add rule for `main`)
- Require a pull request before merging.
- Require status checks to pass (Build, Scorecard, Grype).
- Restrict who can push to matching branches (вкажіть одного користувача або команду, якщо прямий push узагалі дозволено).
- Require approvals (за потребою) та підписані коміти (optional).

CODEOWNERS
- У файлі `.github/CODEOWNERS` вкажіть власника для обов’язкового ревʼю, наприклад:
  - `* @org/maintainers` або `* @username`


