# Quick Start Guide

## Локальні команди

### Ініціалізація проекту

```bash
# Клонувати репозиторій
git clone https://github.com/YourUsername/devsecops-demo.git
cd devsecops-demo

# Переконайтеся, що знаходитеся на гілці main
git checkout main
```

### Збірка проекту

```bash
# Зібрати артефакт (створює build/scan-app-1.0.0.zip)
make build

# Переглянути вміст артефакту
unzip -l build/scan-app-1.0.0.zip

# Очистити build-директорію
make clean
```

### Встановлення залежностей

```bash
# Встановити Python залежності
pip install -r requirements.txt

# Або використовуючи venv
python -m venv venv
source venv/bin/activate  # Linux/Mac
# або
venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

### Робота з гілками

```bash
# Створити feature-гілку
git checkout -b feature/my-feature dev

# Внести зміни та закомітити
git add .
git commit -m "Description of changes"

# Запушити гілку
git push -u origin feature/my-feature

# Створити PR на GitHub через веб-інтерфейс або:
gh pr create --base dev --head feature/my-feature
```

### Створення релізу

```bash
# Переконайтеся, що всі зміни в main
git checkout main
git pull origin main

# Створити тег
git tag -a v1.0.0 -m "Release v1.0.0"

# Запушити тег (автоматично запустить workflow)
git push origin v1.0.0

# Або створити тег для конкретного коміту
git tag -a v1.0.1 -m "Release v1.0.1" <commit-sha>
git push origin v1.0.1
```

### Перегляд workflow статусу

```bash
# Переглянути останні workflow runs (потребує GitHub CLI)
gh run list

# Переглянути конкретний workflow run
gh run view <run-id>

# Переглянути логи workflow
gh run view <run-id> --log

# Завантажити артефакти
gh run download <run-id>
```

## Структура проекту

```
devsecops-demo/
├── .github/
│   └── workflows/
│       ├── build-and-release.yml      # CI/CD pipeline
│       └── security-checks.yml        # Security scanning
├── src/
│   └── 41_scan_stream_default.py      # Код програми
├── build/                              # Build артефакти (ignored)
├── Makefile                            # Build commands
├── requirements.txt                    # Python dependencies
├── .gitignore                          # Ignored files
├── README.md                           # Основна документація
├── SETUP.md                            # Інструкції з налаштування
└── QUICK_START.md                      # Цей файл
```

## Makefile targets

```bash
make all      # Те саме, що і make build
make build    # Зібрати zip-артефакт
make clean    # Видалити build-директорію
```

## GitHub Actions Workflows

### build-and-release.yml
**Тригери:**
- Push в `main`
- Pull request в `main`
- Створення тегу `v*`

**Jobs:**
1. `build` - Збірка артефакту
2. `sbom` - Генерація SBOM за допомогою Syft
3. `cosign-sign` - Підпис артефактів Cosign (keyless OIDC)
4. `release` - Створення GitHub Release (тільки для тегів)

### security-checks.yml
**Тригери:**
- Push в `main`, `stage`, `dev`
- Pull request в `main`
- Щодня о 6:00 UTC (cron)

**Jobs:**
1. `scorecard` - OpenSSF Scorecard аналіз безпеки
2. `sbom` - Генерація SBOM
3. `grype` - Сканування вразливостей (fail на critical)

## Типові сценарії

### Сценарій 1: Додати нову функцію

```bash
# 1. Створіть feature-гілку
git checkout dev
git pull origin dev
git checkout -b feature/new-feature

# 2. Внесіть зміни
# ... edit files ...

# 3. Тестування локально (якщо є)
make build

# 4. Закомітьте
git add .
git commit -m "feat: add new feature"

# 5. Запушіть
git push -u origin feature/new-feature

# 6. Створіть PR: feature/new-feature → dev
# 7. Після approval і merge, видаліть гілку:
git branch -D feature/new-feature
git push origin --delete feature/new-feature
```

### Сценарій 2: Випустити новий реліз

```bash
# 1. Змерджіть всі зміни: dev → stage → main (через PRs)

# 2. На main створіть тег
git checkout main
git pull origin main
git tag -a v1.1.0 -m "Release v1.1.0 - Description"
git push origin v1.1.0

# 3. Перевірте Actions на GitHub
# Workflow створить release автоматично
```

### Сценарій 3: Виправити вразливість

```bash
# 1. Перевірте Grype results
gh run view --log | grep -A 20 "Grype"

# 2. Оновіть залежності
pip install --upgrade <package-name>
pip freeze > requirements.txt

# 3. Перевірте локально
make clean && make build

# 4. Створіть PR з виправленням
git checkout -b fix/security-vulnerability dev
git add requirements.txt
git commit -m "fix: update vulnerable dependency"
git push -u origin fix/security-vulnerability
```

## Перевірка безпеки локально (опціонально)

```bash
# Встановити інструменти
pip install safety bandit

# Перевірити залежності на вразливості
safety check -r requirements.txt

# Статичний аналіз коду
bandit -r src/

# Або використовуючи Grype локально
# (потребує встановлення: https://github.com/anchore/grype)
grype dir:src/
```

## Корисні посилання

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [OpenSSF Scorecard](https://github.com/ossf/scorecard)
- [Syft (SBOM Generator)](https://github.com/anchore/syft)
- [Grype (Vulnerability Scanner)](https://github.com/anchore/grype)
- [Cosign (Signing)](https://github.com/sigstore/cosign)
- [Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)

## Контакти

Для питань та підтримки:
- Створіть Issue на GitHub
- Зверніться до адміністратора репозиторію
