#!/usr/bin/env bash
# ============================================================
# setup.sh — Скрипт встановлення середовища для GNS3 + Python
# Підтримувані ОС: Ubuntu 20.04/22.04/24.04, Parrot OS, Debian 11/12
#
# ВАЖЛИВО: Переконайтеся, що у вас остання версія файлу:
#   git pull origin copilot/prepare-evidence-in-gns3
#   chmod +x setup.sh
#   sudo bash setup.sh
# ============================================================
set -euo pipefail

# ── Кольори ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
warn() { echo -e "${YELLOW}[!!]${NC}  $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && err "Запустіть скрипт від root: sudo bash setup.sh"

# ── Визначення дистрибутиву ──────────────────────────────────
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_ID_LIKE="${ID_LIKE:-}"
        OS_VERSION="${VERSION_ID:-}"
    else
        OS_ID="unknown"
        OS_ID_LIKE=""
        OS_VERSION=""
    fi
}
detect_os

is_ubuntu() { [[ "$OS_ID" == "ubuntu" ]]; }
is_debian_based() {
    [[ "$OS_ID" == "debian" ]] || \
    [[ "$OS_ID" == "parrot" ]] || \
    [[ "$OS_ID_LIKE" == *"debian"* ]]
}

echo -e "${YELLOW}=== Визначено ОС: $OS_ID ${OS_VERSION} ===${NC}"

# ── 1. Оновлення системи ─────────────────────────────────────
echo -e "\n${YELLOW}=== Крок 1: Оновлення системи ===${NC}"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
ok "Систему оновлено"

# ── 2. Базові пакети ─────────────────────────────────────────
echo -e "\n${YELLOW}=== Крок 2: Встановлення базових пакетів ===${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    python3 python3-pip python3-venv \
    git curl wget unzip openssh-client \
    sshpass expect net-tools iputils-ping \
    wireshark-common tcpdump software-properties-common
ok "Базові пакети встановлено"

# ── 3. GNS3 ─────────────────────────────────────────────────
echo -e "\n${YELLOW}=== Крок 3: Встановлення GNS3 ===${NC}"
if command -v gns3server &>/dev/null || command -v gns3 &>/dev/null; then
    ok "GNS3 вже встановлено"
elif is_ubuntu; then
    # Ubuntu: використовуємо офіційний PPA
    add-apt-repository -y ppa:gns3/ppa
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gns3-gui gns3-server ubridge
    ok "GNS3 встановлено через PPA (Ubuntu)"
elif is_debian_based; then
    # Parrot OS / Debian: спочатку спробуємо apt, потім pip
    echo "  Parrot OS / Debian: встановлення GNS3 через pip3..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtwebsockets \
        qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
        vpcs dynamips wireshark 2>/dev/null || true

    # Встановлення ubridge (потрібен для GNS3)
    if ! command -v ubridge &>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ubridge 2>/dev/null || \
        _install_ubridge_from_source
    fi

    # Встановлення GNS3 через pip
    pip3 install --quiet --upgrade gns3-server gns3-gui
    ok "GNS3 встановлено через pip3 (Parrot/Debian)"
else
    warn "Невідома ОС — спробуємо встановити GNS3 через pip3"
    pip3 install --quiet --upgrade gns3-server gns3-gui
fi

# Функція для збірки ubridge з вихідних кодів (якщо пакет недоступний)
_install_ubridge_from_source() {
    warn "ubridge не знайдено в репозиторії — збираємо з вихідних кодів"
    apt-get install -y -qq libpcap-dev cmake build-essential
    TMP_UBRIDGE=$(mktemp -d)
    git clone --depth 1 https://github.com/GNS3/ubridge.git "$TMP_UBRIDGE"
    make -C "$TMP_UBRIDGE"
    install -m 755 "$TMP_UBRIDGE/ubridge" /usr/local/bin/ubridge
    setcap cap_net_raw,cap_net_admin+eip /usr/local/bin/ubridge
    rm -rf "$TMP_UBRIDGE"
    ok "ubridge зібрано та встановлено"
}

# Додаємо поточного користувача до потрібних груп
REALUSER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
for grp in ubridge libvirt kvm wireshark docker; do
    if getent group "$grp" &>/dev/null; then
        usermod -aG "$grp" "$REALUSER" 2>/dev/null || true
    fi
done
ok "Групи налаштовано для $REALUSER"

# ── 4. Docker ─────────────────────────────────────────────────
echo -e "\n${YELLOW}=== Крок 4: Встановлення Docker ===${NC}"
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | bash
    REALUSER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
    usermod -aG docker "$REALUSER"
    systemctl enable --now docker
    ok "Docker встановлено"
else
    ok "Docker вже встановлено ($(docker --version))"
fi

# ── 5. Python-залежності проєкту ─────────────────────────────
echo -e "\n${YELLOW}=== Крок 5: Python-залежності ===${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
    pip3 install --quiet -r "$SCRIPT_DIR/requirements.txt"
    ok "Python-залежності встановлено"
else
    warn "requirements.txt не знайдено; пропускаємо"
fi

# ── 6. Генерація SSH-ключа (якщо відсутній) ──────────────────
echo -e "\n${YELLOW}=== Крок 6: SSH-ключ ===${NC}"
REALUSER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
USER_HOME="$(eval echo "~$REALUSER")"
SSH_KEY="$USER_HOME/.ssh/id_rsa_gns3"
mkdir -p "$USER_HOME/.ssh"
chown "$REALUSER:$REALUSER" "$USER_HOME/.ssh"
if [[ ! -f "$SSH_KEY" ]]; then
    sudo -u "$REALUSER" ssh-keygen -t rsa -b 4096 \
        -f "$SSH_KEY" -N "" \
        -C "gns3-lab-$(hostname)"
    ok "SSH-ключ створено: $SSH_KEY"
else
    ok "SSH-ключ вже існує: $SSH_KEY"
fi

# ── 7. Підсумок ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} Встановлення завершено успішно!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Наступні кроки:"
echo "  1) Перезавантажте систему: sudo reboot"
if is_ubuntu; then
    echo "  2) Запустіть GNS3: gns3"
else
    echo "  2) Запустіть GNS3: python3 -m gns3 (або gns3 якщо pip додав у PATH)"
    echo "     Якщо gns3 не знайдено: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
echo "  3) Імпортуйте IOU/IOSv образи (розділ docs/ПОКРОКОВА_ІНСТРУКЦІЯ.md)"
echo "  4) Запустіть топологію та виконайте:"
echo "       python3 src/deploy_configs.py --inventory inventory.yml"
echo ""
