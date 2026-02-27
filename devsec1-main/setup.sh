#!/usr/bin/env bash
# ============================================================
# setup.sh — Встановлення GNS3 + Python-середовища
# Підтримувані ОС: Parrot OS, Debian 11/12, Ubuntu 20.04/22.04/24.04
#
# Як запустити:
#   sudo bash setup.sh
#
# УВАГА: bash дозволяє в іменах змінних лише ASCII-символи.
# Тому всі імена змінних та функцій — латиниця,
# а повідомлення та коментарі — українською.
# ============================================================
set -euo pipefail

# ── Кольорові повідомлення ───────────────────────────────────
# Стандартні ANSI-коди для кольорового виводу в термінал
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[ОК]${NC}   $*"; }
warn() { echo -e "${YELLOW}[!!]${NC}   $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

# ── Перевірка прав root ──────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Запустіть від root: sudo bash setup.sh"

# ── Визначення реального користувача (не root) ───────────────
# SUDO_USER зберігає ім'я того, хто запустив sudo
REALUSER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
HOME_DIR="$(eval echo "~${REALUSER}")"

# ── Визначення операційної системи ──────────────────────────
# Читаємо /etc/os-release — стандартний файл для всіх сучасних дистрибутивів
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    OS_VER="${VERSION_ID:-}"
else
    OS_ID="unknown"; OS_LIKE=""; OS_VER=""
fi

# is_debian: тільки "чистий" Debian, не Parrot (хоча Parrot теж debian-based,
# він іде у окрему гілку is_parrot щоб уникнути неоднозначності)
is_parrot() { [[ "$OS_ID" == "parrot" ]]; }
is_ubuntu() { [[ "$OS_ID" == "ubuntu" ]]; }
is_debian() { [[ "$OS_ID" == "debian" ]]; }

echo -e "${YELLOW}=== Виявлено ОС: ${OS_ID} ${OS_VER} ===${NC}"

# ============================================================
# ФУНКЦІЇ (оголошуємо до першого виклику — вимога bash)
# ============================================================

# Збирає ubridge з вихідних кодів, якщо пакет відсутній у репозиторіях.
# ubridge потрібен GNS3 для роботи з мережевими інтерфейсами хоста.
build_ubridge() {
    warn "ubridge не знайдено в репозиторіях — збираємо з вихідних кодів GitHub"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        libpcap-dev cmake build-essential
    local TMP_BUILD
    TMP_BUILD=$(mktemp -d)
    git clone --depth 1 https://github.com/GNS3/ubridge.git "$TMP_BUILD"
    make -C "$TMP_BUILD" -s
    install -m 755 "$TMP_BUILD/ubridge" /usr/local/bin/ubridge
    # Встановлюємо capabilities замість setuid — більш безпечно
    setcap cap_net_raw,cap_net_admin+eip /usr/local/bin/ubridge
    rm -rf "$TMP_BUILD"
    ok "ubridge зібрано та встановлено у /usr/local/bin/ubridge"
}

# Встановлює GNS3 через pip3 — метод для Parrot OS та Debian.
# Спочатку встановлює Qt5-залежності через apt (системно),
# потім сам gns3-server і gns3-gui через pip.
install_gns3_pip() {
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
    warn "Деякі пакети недоступні — продовжуємо без них"

    # vpcs та dynamips — емулятори, опціонально
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        vpcs dynamips 2>/dev/null || \
    warn "vpcs/dynamips не знайдено у репозиторіях — можна встановити пізніше"

    # Встановлення ubridge (потрібен для роботи з інтерфейсами хоста)
    if ! command -v ubridge &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ubridge 2>/dev/null || \
        build_ubridge
    fi

    # Встановлення GNS3 через pip3
    # --break-system-packages потрібен на Debian 12+ / Parrot (PEP 668)
    if pip3 install --quiet --upgrade gns3-server gns3-gui 2>/dev/null; then
        ok "GNS3 встановлено через pip3"
    elif pip3 install --quiet --upgrade --break-system-packages \
            gns3-server gns3-gui 2>/dev/null; then
        ok "GNS3 встановлено через pip3 (break-system-packages)"
    else
        err "Не вдалось встановити GNS3 через pip3. Перевірте мережу та спробуйте вручну: pip3 install gns3-server gns3-gui"
    fi
}

# ============================================================
# КРОК 1: Оновлення системи
# ============================================================
echo -e "\n${YELLOW}=== Крок 1: Оновлення системи ===${NC}"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
ok "Систему оновлено"

# ============================================================
# КРОК 2: Базові пакети
# ============================================================
echo -e "\n${YELLOW}=== Крок 2: Базові пакети ===${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    python3 python3-pip python3-venv \
    git curl wget unzip openssh-client \
    sshpass expect net-tools iputils-ping \
    wireshark-common tcpdump \
    software-properties-common
ok "Базові пакети встановлено"

# ============================================================
# КРОК 3: GNS3
# ============================================================
echo -e "\n${YELLOW}=== Крок 3: Встановлення GNS3 ===${NC}"
if command -v gns3server &>/dev/null || command -v gns3 &>/dev/null; then
    ok "GNS3 вже встановлено — пропускаємо"
elif is_parrot || is_debian; then
    # Parrot OS та Debian не підтримують Ubuntu PPA →
    # встановлюємо через pip3 з Qt5 залежностями
    echo "  Parrot OS / Debian: використовуємо pip3-метод..."
    install_gns3_pip
elif is_ubuntu; then
    # Ubuntu: офіційний PPA від розробників GNS3
    add-apt-repository -y ppa:gns3/ppa
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        gns3-gui gns3-server ubridge
    ok "GNS3 встановлено через PPA (Ubuntu)"
else
    # Невідома ОС — пробуємо pip3
    warn "Невідома ОС — пробуємо pip3..."
    install_gns3_pip
fi

# Додаємо користувача до системних груп, потрібних GNS3
for GRP in ubridge libvirt kvm wireshark docker; do
    if getent group "$GRP" &>/dev/null; then
        usermod -aG "$GRP" "$REALUSER" 2>/dev/null || true
    fi
done
ok "Групи налаштовано для ${REALUSER}"

# ============================================================
# КРОК 4: Docker (потрібен для Linux appliances у GNS3)
# ============================================================
echo -e "\n${YELLOW}=== Крок 4: Docker ===${NC}"
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | bash
    usermod -aG docker "$REALUSER"
    systemctl enable --now docker
    ok "Docker встановлено"
else
    ok "Docker вже встановлено ($(docker --version))"
fi

# ============================================================
# КРОК 5: Python-залежності проєкту
# ============================================================
echo -e "\n${YELLOW}=== Крок 5: Python-залежності проєкту ===${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/requirements.txt" ]]; then
    # Спробуємо без --break-system-packages, потім з ним (для Parrot/Debian 12+)
    pip3 install --quiet -r "${SCRIPT_DIR}/requirements.txt" 2>/dev/null || \
    pip3 install --quiet --break-system-packages \
        -r "${SCRIPT_DIR}/requirements.txt"
    ok "Python-залежності встановлено"
else
    warn "requirements.txt не знайдено — пропускаємо"
fi

# ============================================================
# КРОК 6: Генерація SSH-ключа
# ============================================================
echo -e "\n${YELLOW}=== Крок 6: SSH-ключ для підключення до GNS3-пристроїв ===${NC}"
SSH_KEY="${HOME_DIR}/.ssh/id_rsa_gns3"
mkdir -p "${HOME_DIR}/.ssh"
chown "${REALUSER}:${REALUSER}" "${HOME_DIR}/.ssh"
chmod 700 "${HOME_DIR}/.ssh"
if [[ ! -f "$SSH_KEY" ]]; then
    sudo -u "$REALUSER" ssh-keygen -t rsa -b 4096 \
        -f "$SSH_KEY" -N "" \
        -C "gns3-lab-$(hostname)"
    ok "SSH-ключ створено: ${SSH_KEY}"
else
    ok "SSH-ключ вже існує: ${SSH_KEY}"
fi

# ============================================================
# ПІДСУМОК
# ============================================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} Встановлення завершено успішно!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Наступні кроки:"
echo "  1) ОБОВ'ЯЗКОВО перезавантажте систему:"
echo "       sudo reboot"
echo ""
echo "  2) Запустіть GNS3 після перезавантаження:"
if is_ubuntu; then
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
