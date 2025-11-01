# DevSecOps Demo Repository

[![Build, SBOM & Cosign Sign](https://github.com/PetrLion/devs/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/PetrLion/devs/actions/workflows/build-and-release.yml)
[![Security Checks](https://github.com/PetrLion/devs/actions/workflows/security-checks.yml/badge.svg)](https://github.com/PetrLion/devs/actions/workflows/security-checks.yml)

## Опис (Description)

Демонстраційний репозиторій для впровадження DevSecOps практик з використанням GitHub Actions.

**Основні можливості:**
- ✅ **Build** - Автоматична збірка артефактів
- 📋 **SBOM** - Генерація Software Bill of Materials за допомогою Syft
- 🔐 **Cosign Sign** - Підпис артефактів (keyless OIDC)
- 🚀 **Release** - Створення GitHub Release (тільки для тегів)
- 🛡️ **Security** - OpenSSF Scorecard та Grype vulnerability scanning

## Структура гілок (Branch Structure)

Репозиторій використовує **three-branch strategy**:

```
dev → stage → main (з Release)
```

- **`dev`** - розробка та інтеграція функцій
- **`stage`** - тестування перед production
- **`main`** - production-ready код (тільки через Pull Requests)

Детальніше: [.github/BRANCH_STRATEGY.md](.github/BRANCH_STRATEGY.md)

## GitHub Actions Workflows

### 1. Build and Release Pipeline
**Файл**: `.github/workflows/build-and-release.yml`

**Етапи:**
1. **Build** - Збірка артефакту через `make build`
2. **SBOM** - Генерація SBOM за допомогою Syft (CycloneDX JSON)
3. **Cosign Sign** - Підпис артефактів через Cosign з keyless OIDC
4. **Release** - Створення GitHub Release (тільки для тегів v*)

**Тригери:**
- Push до `dev`, `stage`, `main`
- Pull requests до `main`
- Tags `v*`

### 2. Security Checks
**Файл**: `.github/workflows/security-checks.yml`

**Перевірки:**
1. **OpenSSF Scorecard** - Аналіз безпеки репозиторію
2. **Syft** - Генерація SBOM
3. **Grype** - Сканування вразливостей в SBOM

**Тригери:**
- Push до `dev`, `stage`, `main`
- Pull requests до `main`
- Щоденний запуск о 6:00 UTC

## Швидкий старт (Quick Start)

### Локальна збірка

```bash
cd devsec1-main
make build
```

Результат: `devsec1-main/dist/scan-app-*.zip`

### Створення релізу

1. Переконайтесь, що код в `main` гілці
2. Створіть тег:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. GitHub Actions автоматично створить Release з:
   - Build артефактами
   - SBOM файлом
   - Cosign підписами та сертифікатами

## Налаштування репозиторію (Setup)

### 1. Створення гілок

```bash
# Створити dev гілку
git checkout -b dev
git push -u origin dev

# Створити stage гілку
git checkout -b stage
git push -u origin stage

# Повернутись до main
git checkout main
```

### 2. Branch Protection для `main`

В GitHub Settings → Branches → Branch protection rules:

- ✅ Require a pull request before merging
- ✅ Require approvals (мінімум 1)
- ✅ Require status checks to pass:
  - `build`
  - `sbom`
  - `cosign-sign`
  - `scorecard`
  - `grype`
- ✅ Restrict pushes (тільки через PR)

### 3. Collaborators

Settings → Collaborators → Add people

Рекомендовано: додати 4 користувачів, але тільки 1-2 з правами на `main`

## Компоненти проекту

### devsec1-main/
Основний додаток для демонстрації:
- `src/` - Python код (41_scan_stream_default.py)
- `dist/` - Зібрані артефакти
- `Makefile` - Команди для збірки
- `requirements.txt` - Python залежності

### Workflows
- `.github/workflows/build-and-release.yml` - Build pipeline
- `.github/workflows/security-checks.yml` - Security scanning

## Перевірка безпеки (Security)

### OpenSSF Scorecard
Автоматично оцінює безпеку репозиторію за багатьма критеріями.

### Grype Scanning
Сканує SBOM на відомі CVE вразливості. Може зупинити build при критичних проблемах.

### Cosign Signing
Підписує артефакти за допомогою keyless OIDC (без зберігання ключів):
- Використовує GitHub OIDC токен
- Створює `.sig` файли підписів
- Генерує `.crt` сертифікати

## Артефакти в Release

Кожен release містить:
- 📦 `scan-app-*.zip` - зібраний додаток
- 📋 `sbom.json` - Software Bill of Materials
- 🔐 `*.sig` - Cosign підписи
- 📜 `*.crt` - Cosign сертифікати

## Workflow процес

```
┌─────────┐
│   dev   │  ← Feature branches
└────┬────┘
     │ (merge)
     ▼
┌─────────┐
│  stage  │  ← Testing
└────┬────┘
     │ (PR)
     ▼
┌─────────┐
│  main   │  ← Production
└────┬────┘
     │ (tag v*)
     ▼
┌─────────┐
│ Release │  ← GitHub Release with artifacts
└─────────┘
```

## Ліцензія (License)

Demo project for educational purposes.
