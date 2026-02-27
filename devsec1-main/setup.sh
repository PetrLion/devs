#!/usr/bin/env bash
# ============================================================
# setup.sh — Встановлення GNS3 + Python-середовища
# Підтримувані ОС: Parrot OS, Debian 11/12, Ubuntu 20.04/22.04/24.04
#
# Як запустити:
#   sudo bash setup.sh
# ============================================================
set -euo pipefail

# ── Кольорові повідомлення ───────────────────────────────────
ЧЕРВОНИЙ='\033[0;31m'; ЗЕЛЕНИЙ='\033[0;32m'; ЖОВТИЙ='\033[1;33m'; БЕЗ='\033[0m'
ок()      { echo -e "${ЗЕЛЕНИЙ}[ОК]${БЕЗ}   $*"; }
увага()   { echo -e "${ЖОВТИЙ}[!!]${БЕЗ}   $*"; }
помилка() { echo -e "${ЧЕРВОНИЙ}[ERR]${БЕЗ} $*" >&2; exit 1; }

# ── Перевірка прав root ──────────────────────────────────────
[[ $EUID -ne 0 ]] && помилка "Запустіть від root: sudo bash setup.sh"

# ── Визначення реального користувача (не root) ───────────────
# SUDO_USER зберігає ім'я того, хто запустив sudo
РЕАЛЬНИЙ_КОРИСТУВАЧ="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
ДОМ_ДИРЕКТОРІЯ="$(eval echo "~${РЕАЛЬНИЙ_КОРИСТУВАЧ}")"

# ── Визначення операційної системи ──────────────────────────
# Читаємо /etc/os-release — стандартний файл для всіх сучасних дистрибутивів
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    ОС_ID="${ID:-невідомо}"
    ОС_СХОЖІСТЬ="${ID_LIKE:-}"
    ОС_ВЕРСІЯ="${VERSION_ID:-}"
else
    ОС_ID="невідомо"; ОС_СХОЖІСТЬ=""; ОС_ВЕРСІЯ=""
fi

# це_debian: тільки "чистий" Debian, не Parrot (хоча Parrot теж debian-based,
# він іде у окрему гілку це_parrot щоб уникнути неоднозначності)
це_parrot()  { [[ "$ОС_ID" == "parrot" ]]; }
це_ubuntu()  { [[ "$ОС_ID" == "ubuntu" ]]; }
це_debian()  { [[ "$ОС_ID" == "debian" ]]; }

echo -e "${ЖОВТИЙ}=== Виявлено ОС: ${ОС_ID} ${ОС_ВЕРСІЯ} ===${БЕЗ}"

# ============================================================
# ФУНКЦІЇ (оголошуємо до першого виклику — вимога bash)
# ============================================================

# Збирає ubridge з вихідних кодів, якщо пакет відсутній у репозиторіях.
# ubridge потрібен GNS3 для роботи з мережевими інтерфейсами хоста.
_зібрати_ubridge() {
    увага "ubridge не знайдено в репозиторіях — збираємо з вихідних кодів GitHub"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        libpcap-dev cmake build-essential
    local ТИМЧ
    ТИМЧ=$(mktemp -d)
    git clone --depth 1 https://github.com/GNS3/ubridge.git "$ТИМЧ"
    make -C "$ТИМЧ" -s
    install -m 755 "$ТИМЧ/ubridge" /usr/local/bin/ubridge
    # Встановлюємо capabilities замість setuid — більш безпечно
    setcap cap_net_raw,cap_net_admin+eip /usr/local/bin/ubridge
    rm -rf "$ТИМЧ"
    ок "ubridge зібрано та встановлено у /usr/local/bin/ubridge"
}

# Встановлює GNS3 через pip3 — метод для Parrot OS та Debian.
# Спочатку встановлює Qt5-залежності через apt (системно),
# потім сам gns3-server і gns3-gui через pip.
_встановити_gns3_pip() {
    echo "  Встановлення Qt5 та мережевих залежностей через apt..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        python3-pyqt5 \
        python3-pyqt5.qtsvg \
        python3-pyqt5.qtwebsockets \
        qemu-kvm \
        libvirt-daemon-system \
        libvirt-clients \
        bridge-utils \
        wireshark 2>/dev/null || \
    увага "Деякі пакети недоступні — продовжуємо без них"

    # vpcs та dynamips — емулятори, опціонально
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        vpcs dynamips 2>/dev/null || \
    увага "vpcs/dynamips не знайдено у репозиторіях — можна встановити пізніше"

    # Встановлення ubridge
    if ! command -v ubridge &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ubridge 2>/dev/null || \
        _зібрати_ubridge
    fi

    # Встановлення GNS3 через pip3
    # --break-system-packages потрібен на Debian 12+ / Parrot (PEP 668)
    if pip3 install --quiet --upgrade gns3-server gns3-gui 2>/dev/null; then
        ок "GNS3 встановлено через pip3"
    elif pip3 install --quiet --upgrade --break-system-packages \
            gns3-server gns3-gui 2>/dev/null; then
        ок "GNS3 встановлено через pip3 (break-system-packages)"
    else
        помилка "Не вдалось встановити GNS3 через pip3. Перевірте підключення до мережі та спробуйте вручну: pip3 install gns3-server gns3-gui"
    fi
}

# ============================================================
# КРОК 1: Оновлення системи
# ============================================================
echo -e "\n${ЖОВТИЙ}=== Крок 1: Оновлення системи ===${БЕЗ}"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
ок "Систему оновлено"

# ============================================================
# КРОК 2: Базові пакети
# ============================================================
echo -e "\n${ЖОВТИЙ}=== Крок 2: Базові пакети ===${БЕЗ}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    python3 python3-pip python3-venv \
    git curl wget unzip openssh-client \
    sshpass expect net-tools iputils-ping \
    wireshark-common tcpdump \
    software-properties-common
ок "Базові пакети встановлено"

# ============================================================
# КРОК 3: GNS3
# ============================================================
echo -e "\n${ЖОВТИЙ}=== Крок 3: Встановлення GNS3 ===${БЕЗ}"
if command -v gns3server &>/dev/null || command -v gns3 &>/dev/null; then
    ок "GNS3 вже встановлено — пропускаємо"
elif це_parrot || це_debian; then
    # Parrot OS та Debian не підтримують Ubuntu PPA →
    # встановлюємо через pip3 з Qt5 залежностями
    echo "  Parrot OS / Debian: використовуємо pip3-метод..."
    _встановити_gns3_pip
elif це_ubuntu; then
    # Ubuntu: офіційний PPA від розробників GNS3
    add-apt-repository -y ppa:gns3/ppa
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        gns3-gui gns3-server ubridge
    ок "GNS3 встановлено через PPA (Ubuntu)"
else
    # Невідома ОС — пробуємо pip3
    увага "Невідома ОС — пробуємо pip3..."
    _встановити_gns3_pip
fi

# Додаємо користувача до системних груп, потрібних GNS3
for ГРУПА in ubridge libvirt kvm wireshark docker; do
    if getent group "$ГРУПА" &>/dev/null; then
        usermod -aG "$ГРУПА" "$РЕАЛЬНИЙ_КОРИСТУВАЧ" 2>/dev/null || true
    fi
done
ок "Групи налаштовано для ${РЕАЛЬНИЙ_КОРИСТУВАЧ}"

# ============================================================
# КРОК 4: Docker (потрібен для Linux appliances у GNS3)
# ============================================================
echo -e "\n${ЖОВТИЙ}=== Крок 4: Docker ===${БЕЗ}"
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | bash
    usermod -aG docker "$РЕАЛЬНИЙ_КОРИСТУВАЧ"
    systemctl enable --now docker
    ок "Docker встановлено"
else
    ок "Docker вже встановлено ($(docker --version))"
fi

# ============================================================
# КРОК 5: Python-залежності проєкту
# ============================================================
echo -e "\n${ЖОВТИЙ}=== Крок 5: Python-залежності проєкту ===${БЕЗ}"
ДИРЕКТОРІЯ_СКРИПТУ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${ДИРЕКТОРІЯ_СКРИПТУ}/requirements.txt" ]]; then
    # Спробуємо без --break-system-packages, потім з ним (для Parrot/Debian 12+)
    pip3 install --quiet -r "${ДИРЕКТОРІЯ_СКРИПТУ}/requirements.txt" 2>/dev/null || \
    pip3 install --quiet --break-system-packages \
        -r "${ДИРЕКТОРІЯ_СКРИПТУ}/requirements.txt"
    ок "Python-залежності встановлено"
else
    увага "requirements.txt не знайдено — пропускаємо"
fi

# ============================================================
# КРОК 6: Генерація SSH-ключа
# ============================================================
echo -e "\n${ЖОВТИЙ}=== Крок 6: SSH-ключ для підключення до GNS3-пристроїв ===${БЕЗ}"
ШЛЯХ_КЛЮЧА="${ДОМ_ДИРЕКТОРІЯ}/.ssh/id_rsa_gns3"
mkdir -p "${ДОМ_ДИРЕКТОРІЯ}/.ssh"
chown "${РЕАЛЬНИЙ_КОРИСТУВАЧ}:${РЕАЛЬНИЙ_КОРИСТУВАЧ}" "${ДОМ_ДИРЕКТОРІЯ}/.ssh"
chmod 700 "${ДОМ_ДИРЕКТОРІЯ}/.ssh"
if [[ ! -f "$ШЛЯХ_КЛЮЧА" ]]; then
    sudo -u "$РЕАЛЬНИЙ_КОРИСТУВАЧ" ssh-keygen -t rsa -b 4096 \
        -f "$ШЛЯХ_КЛЮЧА" -N "" \
        -C "gns3-lab-$(hostname)"
    ок "SSH-ключ створено: ${ШЛЯХ_КЛЮЧА}"
else
    ок "SSH-ключ вже існує: ${ШЛЯХ_КЛЮЧА}"
fi

# ============================================================
# ПІДСУМОК
# ============================================================
echo ""
echo -e "${ЗЕЛЕНИЙ}============================================${БЕЗ}"
echo -e "${ЗЕЛЕНИЙ} Встановлення завершено успішно!${БЕЗ}"
echo -e "${ЗЕЛЕНИЙ}============================================${БЕЗ}"
echo ""
echo "  Наступні кроки:"
echo "  1) ОБОВ'ЯЗКОВО перезавантажте систему:"
echo "       sudo reboot"
echo ""
echo "  2) Запустіть GNS3 після перезавантаження:"
if це_ubuntu; then
    echo "       gns3"
else
    # pip3 встановлює у ~/.local/bin — додаємо до PATH постійно
    echo "       gns3"
    echo "     Якщо 'gns3: command not found' — виконайте один раз:"
    echo "       echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "       source ~/.bashrc"
    echo "     Або запустіть напряму:"
    echo "       python3 -m gns3"
fi
echo ""
echo "  3) Перейдіть до інструкції:"
echo "       cat docs/ПОКРОКОВА_ІНСТРУКЦІЯ.md"
echo ""
echo "  4) Після побудови топології в GNS3 запустіть деплой:"
echo "       python3 src/deploy_configs.py --inventory inventory.yml --dry-run"
echo ""
