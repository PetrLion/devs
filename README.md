# DevSecOps Demo Repository

## 🚀 Швидкий старт

```bash
# Створити три гілки (dev, stage, main)
./setup-branches.sh

# Зібрати проект
make build
```

Детальні інструкції: [SETUP.md](SETUP.md) | [QUICK_START.md](QUICK_START.md)

## Опис

- Імпорт уразливого прикладу коду (`src/41_scan_stream_default.py`).
- Автоматична збірка та реліз через GitHub Actions.
- Підпис артефакту за допомогою Cosign (keyless OIDC).
- Генерація SBOM (Syft) та перевірка SBOM (Grype).
- Перевірка безпеки репозиторію (OpenSSF Scorecard).
- Гілки `dev`, `stage`, `main` з політикою внесення змін лише через Merge Request в `main`.

## Алгоритм виконання (DevOps)

### 1) Підготовка репозиторію

- Створити на GitHub публічний репозиторій.
- Клонувати локально та додати файли з цього прикладу.
- Додати чотирьох користувачів до репозиторію через Settings → Collaborators; лише одному надати право push у `main` або повністю заборонити прямий push через Branch protection (рекомендовано).

### 2) Гілки та політики

**Швидке налаштування гілок:**
```bash
# Запустіть скрипт для автоматичного створення гілок
./setup-branches.sh
```

Або вручну створити гілки: `dev`, `stage`, `main`.

**Branch protection для `main`:**
- Увімкнути Branch protection для `main`:
  - Require a pull request before merging.
  - Require status checks to pass (build, scorecard, grype).
  - Restrict who can push.

### 3) Збірка і реліз

**Пайплайн GitHub Actions:**

- **Завантаження коду (Checkout)** → **Налаштування Python-середовища** → **Збірка артефакту («псевдобінаря»)** через `make build`.
  - Встановлюється версія Python (наприклад, 3.11), а також залежності, якщо вони є.
  - Це дозволяє виконати make build і подальші кроки аналізу.
  - Збірка артефакту («псевдобінаря»)
  - Виконується команда make build, яка створює zip-архів (або інший формат), що містить вихідний код.
  - Цей архів є результатом збірки, який буде опубліковано у релізі.

- **Генерація SBOM (Syft)** → **Перевірка SBOM на вразливості (Grype)** → **Підпис артефакту (Cosign, keyless)** → **Завантаження у реліз 1.0.0**.
  - Використовується Syft, який аналізує репозиторій або зібраний артефакт і створює файли SBOM (наприклад, sbom.json).
  - SBOM містить перелік усіх залежностей і використаних компонентів.
  - Перевірка SBOM на вразливості. Виконується Grype, який перевіряє SBOM на відомі CVE та може зупинити пайплайн, якщо знайдено критичні проблеми (політика визначається командою).
  - Підпис артефакту (Cosign, без ключів — Keyless Signing). Cosign через OIDC GitHub Actions підписує зібраний артефакт і SBOM.

**У реліз додаються:**
- zip-архів (build-артефакт),
- файл SBOM,
- підпис Cosign та сертифікат.

- **Збереження build-артефактів**. Пайплайн зберігає результати (артефакти збірки, SBOM) як artifacts, щоб команда могла завантажити їх безпосередньо з CI.

### 4) Перевірки безпеки

- **OpenSSF Scorecard**: workflow запускається на `push`/`schedule`, публікує результати як артефакти.
- **Grype**: запускається на `push`/`pull_request`, сканує SBOM і фейлить білд у разі критичних вразливостей (політика за потребою).

## Локальні команди

```bash
git init
git branch -M main
mkdir -p src
# завантажити файл у src/41_scan_stream_default.py
make build
```

## Реліз 1.0.0

- Створіть тег `v1.0.0` і пушніть у репозиторій. Пайплайн збере артефакт, підпише Cosign, додасть SBOM і створить GitHub Release.

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Перевірки

- Scorecard запускається автоматично.
- Grype запускається автоматично і перевіряє SBOM.

## Структура проекту

```
.
├── .github/
│   └── workflows/
│       ├── build-and-release.yml    # Збірка, SBOM, Cosign, реліз
│       └── security-checks.yml      # Scorecard, Grype
├── src/
│   └── 41_scan_stream_default.py    # Уразливий приклад коду
├── Makefile                          # Команди для збірки
├── requirements.txt                  # Python залежності
└── README.md                         # Ця документація
```

## Workflows

### Build and Release (`build-and-release.yml`)

Виконується при:
- Push в `main`
- Pull request в `main`
- Створення тегу `v*`

Кроки:
1. **Build** - збірка артефакту
2. **SBOM** - генерація SBOM за допомогою Syft
3. **Cosign Sign** - підпис артефактів (keyless OIDC)
4. **Release** - створення GitHub Release (тільки для тегів)

### Security Checks (`security-checks.yml`)

Виконується при:
- Push в `main`, `stage`, `dev`
- Pull request в `main`
- За розкладом (щодня о 6:00 UTC)

Кроки:
1. **Scorecard** - аналіз безпеки репозиторію (OpenSSF Scorecard)
2. **SBOM** - генерація SBOM
3. **Grype** - сканування на вразливості (fail-build на critical)
