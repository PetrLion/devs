#!/usr/bin/env python3
"""
security_audit.py — Автоматизований аудит безпеки за стандартом CIS Benchmark для пристроїв Cisco IOS.

Підключається до кожного пристрою з inventory.yml, виконує серію перевірок та
виводить результати з кольоровим кодуванням рівнів критичності.

Використання:
    python3 security_audit.py [--inventory inventory.yml]
"""

import argparse
import sys
import yaml
from netmiko import ConnectHandler, NetmikoTimeoutException, NetmikoAuthenticationException

# ANSI-коди кольорів
RED = "\033[91m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
RESET = "\033[0m"
BOLD = "\033[1m"


def load_inventory(path: str) -> dict:
    with open(path, "r") as fh:
        return yaml.safe_load(fh)


def check_telnet(output_run_all: str) -> tuple[str, str]:
    """CIS 1.1 — Telnet має бути вимкнено на всіх лініях VTY."""
    if "transport input telnet" in output_run_all.lower():
        return "CRITICAL", "Telnet УВІМКНЕНО на лініях VTY (transport input telnet)"
    if "transport input ssh" in output_run_all.lower():
        return "PASS", "На лініях VTY дозволено лише SSH"
    return "WARNING", "Параметр transport input на лініях VTY явно не налаштовано"


def check_ssh_version(output_run_all: str) -> tuple[str, str]:
    """CIS 1.2 — Має бути налаштована версія SSH 2."""
    if "ip ssh version 2" in output_run_all.lower():
        return "PASS", "SSH версії 2 налаштовано"
    if "ip ssh version 1" in output_run_all.lower():
        return "CRITICAL", "Налаштовано SSH версії 1 — оновіть до версії 2"
    return "WARNING", "SSH версію явно не встановлено на 2"


def check_password_encryption(output_run_all: str) -> tuple[str, str]:
    """CIS 1.3 — Має бути увімкнено сервіс шифрування паролів."""
    if "service password-encryption" in output_run_all.lower():
        return "PASS", "Сервіс шифрування паролів увімкнено"
    return "WARNING", "Сервіс шифрування паролів НЕ увімкнено (відсутній service password-encryption)"


def check_login_banner(output_run_all: str) -> tuple[str, str]:
    """CIS 1.4 — Має бути присутній банер входу (MOTD)."""
    if "banner motd" in output_run_all.lower() or "banner login" in output_run_all.lower():
        return "PASS", "Банер входу налаштовано"
    return "WARNING", "Банер входу не налаштовано"


def check_acl_on_vty(output_run_all: str) -> tuple[str, str]:
    """CIS 1.5 — На лініях VTY має бути застосований ACL access-class."""
    if "access-class" in output_run_all.lower():
        return "PASS", "ACL (access-class) застосовано на лініях VTY"
    return "WARNING", "ACL на лініях VTY не застосовано"


def check_aaa(output_run_all: str) -> tuple[str, str]:
    """CIS 1.6 — Має бути увімкнено AAA new-model."""
    if "aaa new-model" in output_run_all.lower():
        return "PASS", "AAA new-model увімкнено"
    return "WARNING", "AAA new-model НЕ увімкнено"


CHECKS = [
    check_telnet,
    check_ssh_version,
    check_password_encryption,
    check_login_banner,
    check_acl_on_vty,
    check_aaa,
]


def severity_label(severity: str) -> str:
    if severity == "CRITICAL":
        return f"{RED}{BOLD}[CRITICAL]{RESET}"
    if severity == "WARNING":
        return f"{YELLOW}[WARNING] {RESET}"
    return f"{GREEN}[PASS]    {RESET}"


def audit_device(device: dict) -> list[dict]:
    conn_params = {
        "device_type": device["device_type"],
        "host": device["host"],
        "username": device["username"],
        "password": device["password"],
        "timeout": 10,
    }
    results = []
    try:
        with ConnectHandler(**conn_params) as conn:
            running_config = conn.send_command("show running-config")
            for check_fn in CHECKS:
                severity, message = check_fn(running_config)
                results.append({"severity": severity, "message": message})
    except (NetmikoTimeoutException, NetmikoAuthenticationException) as exc:
        results.append({"severity": "CRITICAL",
                        "message": f"Неможливо підключитись до пристрою: {exc}"})
    return results


def print_device_report(device: dict, findings: list[dict]) -> None:
    print(f"\n{'='*60}")
    print(f"  Пристрій: {BOLD}{device['name']}{RESET} ({device['host']}) — роль: {device.get('role', 'н/д')}")
    print(f"{'='*60}")
    for finding in findings:
        label = severity_label(finding["severity"])
        print(f"  {label} {finding['message']}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Аудит безпеки CIS Benchmark для Cisco IOS")
    parser.add_argument("--inventory", default="inventory.yml", help="Шлях до файлу інвентаризації YAML")
    args = parser.parse_args()

    inventory = load_inventory(args.inventory)
    devices = inventory.get("devices", [])
    print(f"[*] Запуск аудиту безпеки для {len(devices)} пристрій(ів) …")

    overall_critical = 0
    for device in devices:
        print(f"[*] Аудит {device['name']} ({device['host']}) …")
        findings = audit_device(device)
        print_device_report(device, findings)
        overall_critical += sum(1 for f in findings if f["severity"] == "CRITICAL")

    print(f"\n{'='*60}")
    if overall_critical:
        print(f"{RED}{BOLD}  Аудит завершено: виявлено {overall_critical} КРИТИЧНИХ порушень!{RESET}")
        sys.exit(1)
    else:
        print(f"{GREEN}{BOLD}  Аудит завершено: критичних порушень не виявлено.{RESET}")


if __name__ == "__main__":
    main()
