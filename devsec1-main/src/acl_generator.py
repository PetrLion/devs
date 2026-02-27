#!/usr/bin/env python3
"""
acl_generator.py — Генератор конфігурацій ACL на основі шаблонів Jinja2 для Cisco IOS.

Зчитує дані про зловмисника/мережу з inventory.yml, відтворює шаблон Jinja2
з templates/acl_block.j2 та зберігає результат у configs/<device_name>_acl.cfg.
За потреби застосовує згенеровану конфігурацію до пристрою через SSH (прапор --apply).

Використання:
    python3 acl_generator.py [--inventory inventory.yml] [--templates templates/] [--apply]
"""

import argparse
import os
import sys
import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined


def load_inventory(path: str) -> dict:
    with open(path, "r") as fh:
        return yaml.safe_load(fh)


def render_acl(template_dir: str, context: dict) -> str:
    env = Environment(
        loader=FileSystemLoader(template_dir),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
    )
    template = env.get_template("acl_block.j2")
    return template.render(**context)


def apply_config(device: dict, config_text: str) -> None:
    """Надіслати згенеровані рядки конфігурації на пристрій через netmiko."""
    try:
        from netmiko import ConnectHandler, NetmikoTimeoutException, NetmikoAuthenticationException
    except ImportError:
        print("  [ПОМИЛКА] netmiko не встановлено. Виконайте: pip install netmiko", file=sys.stderr)
        return

    conn_params = {
        "device_type": device["device_type"],
        "host": device["host"],
        "username": device["username"],
        "password": device["password"],
        "timeout": 10,
    }
    config_lines = [
        line for line in config_text.splitlines()
        if line.strip() and not line.strip().startswith("!")
    ]
    try:
        with ConnectHandler(**conn_params) as conn:
            output = conn.send_config_set(config_lines)
            print(f"  [+] Конфігурацію надіслано на {device['name']}:\n{output}")
    except Exception as exc:
        print(f"  [ПОМИЛКА] Не вдалось надіслати конфігурацію на {device['name']}: {exc}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(description="Генерація конфігурацій ACL для Cisco IOS на основі шаблонів Jinja2")
    parser.add_argument("--inventory", default="inventory.yml", help="Шлях до файлу інвентаризації YAML")
    parser.add_argument("--templates", default="templates", help="Директорія з шаблонами Jinja2")
    parser.add_argument("--output-dir", default="configs", help="Директорія для збережених конфігурацій")
    parser.add_argument("--apply", action="store_true", help="Застосувати згенеровану конфігурацію на пристрої через SSH")
    args = parser.parse_args()

    inventory = load_inventory(args.inventory)
    devices = inventory.get("devices", [])

    context = {
        "attacker_network": inventory.get("attacker_network", "192.168.1.3"),
        "attacker_wildcard": inventory.get("attacker_wildcard", "0.0.0.0"),
        "protected_interface": inventory.get("protected_interface", "GigabitEthernet0/0"),
    }

    os.makedirs(args.output_dir, exist_ok=True)

    print(f"[*] Відтворення ACL-шаблону для {len(devices)} пристрій(ів) …")
    config_text = render_acl(args.templates, context)

    for device in devices:
        if device.get("role") == "main":
            out_path = os.path.join(args.output_dir, f"{device['name']}_acl.cfg")
            with open(out_path, "w") as fh:
                fh.write(config_text)
            print(f"[+] Конфігурацію збережено: {out_path}")

            if args.apply:
                print(f"[*] Застосування конфігурації на {device['name']} ({device['host']}) …")
                apply_config(device, config_text)

    print("[+] Генерацію ACL завершено.")


if __name__ == "__main__":
    main()
