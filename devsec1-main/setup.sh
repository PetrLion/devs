#!/usr/bin/env bash
# ============================================================
# setup.sh — Скрипт встановлення середовища для GNS3 + Python
# Підтримувані ОС: Ubuntu 22.04 / Debian 12
# Запуск:  chmod +x setup.sh && sudo ./setup.sh
# ============================================================
set -euo pipefail

# ── Кольори ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
warn() { echo -e "${YELLOW}[!!]${NC}  $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && err "Запустіть скрипт від root (sudo ./setup.sh)"

# ── 1. Оновлення системи ─────────────────────────────────────
echo -e "\n${YELLOW}=== Крок 1: Оновлення системи ===${NC}"
apt-get update -qq
apt-get upgrade -y -qq
ok "Систему оновлено"

# ── 2. Базові пакети ─────────────────────────────────────────
echo -e "\n${YELLOW}=== Крок 2: Встановлення базових пакетів ===${NC}"
apt-get install -y -qq \
    python3 python3-pip python3-venv \
    git curl wget unzip openssh-client \
    sshpass expect net-tools iputils-ping \
    wireshark-common tcpdump
ok "Базові пакети встановлено"

# ── 3. GNS3 ─────────────────────────────────────────────────
echo -e "\n${YELLOW}=== Крок 3: Встановлення GNS3 ===${NC}"
if ! command -v gns3server &>/dev/null; then
    add-apt-repository -y ppa:gns3/ppa 2>/dev/null || true
    apt-get update -qq
    apt-get install -y -qq gns3-gui gns3-server
    # Додаємо поточного користувача до потрібних груп
    REALUSER="${SUDO_USER:-$(logname)}"
    usermod -aG ubridge,libvirt,kvm,wireshark,docker "$REALUSER" 2>/dev/null || true
    ok "GNS3 встановлено"
else
    ok "GNS3 вже встановлено ($(gns3server --version 2>/dev/null || echo 'версія невідома'))"
fi

# ── 4. Docker (потрібен для GNS3 appliances) ─────────────────
echo -e "\n${YELLOW}=== Крок 4: Встановлення Docker ===${NC}"
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | bash
    REALUSER="${SUDO_USER:-$(logname)}"
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
REALUSER="${SUDO_USER:-$(logname)}"
USER_HOME="$(eval echo "~$REALUSER")"
SSH_KEY="$USER_HOME/.ssh/id_rsa_gns3"
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
echo "  2) Запустіть GNS3: gns3"
echo "  3) Імпортуйте IOU/IOSv образи (розділ docs/ПОКРОКОВА_ІНСТРУКЦІЯ.md)"
echo "  4) Запустіть топологію та виконайте:"
echo "       python3 src/deploy_configs.py --inventory inventory.yml"
echo ""
