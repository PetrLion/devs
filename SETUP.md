# Інструкція з налаштування DevSecOps Demo Repository

## Крок 1: Підготовка репозиторію

### 1.1 Створення публічного репозиторію на GitHub
- Відкрийте GitHub та створіть новий публічний репозиторій
- Назвіть його, наприклад: `devsecops-demo`

### 1.2 Додавання користувачів
1. Перейдіть в **Settings** → **Collaborators and teams**
2. Натисніть **Add people**
3. Додайте 4 користувачів до репозиторію
4. Налаштуйте права доступу (рекомендація: через branch protection)

## Крок 2: Створення гілок

```bash
# Перевірте, що ви на гілці main
git checkout main

# Створіть гілку dev
git checkout -b dev
git push -u origin dev

# Створіть гілку stage
git checkout -b stage
git push -u origin stage

# Поверніться на main
git checkout main
```

## Крок 3: Налаштування Branch Protection для main

### 3.1 Перейдіть в Settings → Branches → Add rule

### 3.2 Налаштування правил для гілки `main`:

#### Branch name pattern
- `main`

#### Protect matching branches
✅ **Require a pull request before merging**
- ✅ Require approvals: `1` (або більше)
- ✅ Dismiss stale pull request approvals when new commits are pushed

✅ **Require status checks to pass before merging**
- ✅ Require branches to be up to date before merging
- **Status checks required:**
  - `Build Project`
  - `OpenSSF Scorecard`
  - `Scan with Grype`

✅ **Restrict who can push to matching branches**
- Додайте тільки одного користувача (адміністратора) або залиште порожнім для повної заборони прямого push

✅ **Do not allow bypassing the above settings**

### 3.3 Додаткові рекомендовані налаштування:
- ✅ Require linear history
- ✅ Include administrators (для дотримання правил усіма)
- ✅ Allow force pushes: **Вимкнено**
- ✅ Allow deletions: **Вимкнено**

## Крок 4: Налаштування Security

### 4.1 Security & analysis
Перейдіть в **Settings** → **Security & analysis** і увімкніть:
- ✅ Dependency graph
- ✅ Dependabot alerts
- ✅ Dependabot security updates
- ✅ Code scanning with CodeQL (опціонально)
- ✅ Secret scanning

### 4.2 Токени для GitHub Actions
GitHub Actions автоматично отримує доступ через `GITHUB_TOKEN`. Для Cosign keyless signing потрібні:
- ✅ `id-token: write` - для OIDC (вже налаштовано в workflow)
- ✅ `contents: write` - для створення релізів (вже налаштовано в workflow)

## Крок 5: Перевірка налаштувань

### 5.1 Створіть тестовий Pull Request

```bash
# Створіть тестову гілку
git checkout -b test-pr dev

# Внесіть невелику зміну
echo "# Test PR" >> test.md

# Закомітьте та запушіть
git add test.md
git commit -m "Test PR for branch protection"
git push -u origin test-pr
```

### 5.2 Створіть PR на GitHub
- Перейдіть на GitHub
- Створіть Pull Request з `test-pr` в `main`
- Перевірте, що:
  - ✅ Workflows запустилися автоматично
  - ✅ Status checks відображаються
  - ✅ Кнопка Merge заблокована до виконання всіх checks

### 5.3 Видаліть тестову гілку після перевірки
```bash
git checkout main
git branch -D test-pr
git push origin --delete test-pr
```

## Крок 6: Створення релізу v1.0.0

### 6.1 Переконайтеся, що всі зміни в main

```bash
git checkout main
git pull origin main
```

### 6.2 Створіть та запушіть тег

```bash
# Створіть тег v1.0.0
git tag -a v1.0.0 -m "Release v1.0.0 - Initial DevSecOps Demo"

# Запушіть тег
git push origin v1.0.0
```

### 6.3 Перевірте реліз
- Workflow `build-and-release.yml` запуститься автоматично
- Після успішного виконання перевірте **Releases** на GitHub
- Ви побачите:
  - 📦 `scan-app-1.0.0.zip` - зібраний артефакт
  - 📋 `sbom.json` - Software Bill of Materials
  - 🔐 `*.sig` - Cosign підписи
  - 📜 `*.crt` - Cosign сертифікати

## Крок 7: Перевірка Security Checks

### 7.1 OpenSSF Scorecard
- Перейдіть в **Actions** → **Security Checks - Scorecard & Grype**
- Перевірте результати Scorecard
- Завантажте артефакт `scorecard-results` для детального аналізу

### 7.2 Grype Vulnerability Scan
- В тому ж workflow перевірте результати Grype
- Якщо є критичні вразливості, build зафейлиться
- Завантажте артефакт `grype-results` для аналізу

### 7.3 Security tab
- Перейдіть в **Security** → **Security overview**
- Перевірте Scorecard results
- Перевірте Code scanning alerts (якщо є)

## Робочий процес (Workflow)

### Внесення змін через Pull Request

```bash
# 1. Створіть feature-гілку з dev
git checkout dev
git pull origin dev
git checkout -b feature/my-feature

# 2. Внесіть зміни
# ... редагуйте файли ...

# 3. Закомітьте зміни
git add .
git commit -m "Add my feature"

# 4. Запушіть гілку
git push -u origin feature/my-feature

# 5. Створіть PR на GitHub: feature/my-feature → dev
# 6. Після approval, змерджіть в dev

# 7. Коли готові до stage, створіть PR: dev → stage
# 8. Коли готові до production, створіть PR: stage → main
# 9. Після мерджу в main, створіть новий тег для релізу
```

## Troubleshooting

### Workflow не запускається
- Перевірте права доступу в Settings → Actions → General
- Переконайтеся, що **Allow all actions and reusable workflows** увімкнено
- Перевірте, що workflow файли в правильній директорії: `.github/workflows/`

### Cosign підпис не працює
- Перевірте, що в workflow є `permissions: id-token: write`
- Для релізів потрібно `contents: write`

### Grype фейлить build
- Це нормально, якщо знайдено критичні вразливості
- Перевірте лог Grype для деталей
- Оновіть залежності або змініть `severity-cutoff` в workflow

### Branch protection блокує мердж
- Переконайтеся, що всі required status checks пройшли
- Перевірте, що є необхідна кількість approvals
- Перевірте, що гілка up-to-date з base branch

## Корисні команди

```bash
# Перевірити статус гілок
git branch -a

# Перевірити теги
git tag -l

# Переглянути branch protection rules (через GitHub CLI)
gh api repos/{owner}/{repo}/branches/main/protection

# Переглянути останні workflow runs
gh run list

# Переглянути деталі workflow run
gh run view {run-id}
```
