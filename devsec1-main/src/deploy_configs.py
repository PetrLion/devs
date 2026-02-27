#!/usr/bin/env python3
"""
deploy_configs.py — Розгортання конфігурацій на всі пристрої топології.

Читає inventory.yml, для кожного Cisco IOS/ASA пристрою відтворює
шаблони Jinja2 і надсилає конфігурацію через SSH (netmiko).

Використання:
    python3 deploy_configs.py [--inventory inventory.yml] [--templates templates/]
                              [--dry-run] [--device НАЗВА]
"""

import argparse
import os
import sys
import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined

LINUX_DEVICE_TYPES = {"linux"}
CISCO_DEVICE_TYPES = {"cisco_ios", "cisco_asa", "cisco_nxos"}

# Відповідність ролей → шаблонів (у порядку застосування)
ROLE_TEMPLATES: dict[str, list[str]] = {
    "edge":         ["base_config.j2", "ospf_config.j2"],
    "firewall":     ["base_config.j2", "dmz_acl.j2"],
    "core":         ["base_config.j2", "vlan_config.j2", "ospf_config.j2"],
    "distribution": ["base_config.j2", "vlan_config.j2"],
    "access":       ["base_config.j2", "vlan_config.j2"],
    "server":       [],   # Linux-сервери конфігуруються окремо
    "dmz_server":   [],
}


def load_inventory(path: str) -> dict:
    with open(path, "r") as fh:
        return yaml.safe_load(fh)


def render_template(env: Environment, template_name: str, context: dict) -> str:
    """Відтворити шаблон. Повертає порожній рядок, якщо шаблон не існує."""
    try:
        tpl = env.get_template(template_name)
        return tpl.render(**context)
    except Exception as exc:
        print(f"  [ПОПЕРЕДЖЕННЯ] Шаблон {template_name}: {exc}", file=sys.stderr)
        return ""


def push_to_device(device: dict, config_text: str) -> bool:
    """Надіслати конфігурацію на Cisco-пристрій через netmiko."""
    try:
        from netmiko import ConnectHandler, NetmikoTimeoutException, NetmikoAuthenticationException
    except ImportError:
        print("  [ПОМИЛКА] netmiko не встановлено. Виконайте: pip install netmiko",
              file=sys.stderr)
        return False

    conn_params = {
        "device_type": device["device_type"],
        "host": device["host"],
        "username": device["username"],
        "password": device["password"],
        "timeout": 30,
    }
    config_lines = [
        line for line in config_text.splitlines()
        if line.strip() and not line.strip().startswith("!")
    ]
    try:
        with ConnectHandler(**conn_params) as conn:
            output = conn.send_config_set(config_lines)
            conn.save_config()
            print(f"  [+] Конфігурацію надіслано на {device['name']} — {len(config_lines)} рядків")
            if "--verbose" in sys.argv:
                print(output)
        return True
    except Exception as exc:
        print(f"  [ПОМИЛКА] {device['name']} ({device['host']}): {exc}", file=sys.stderr)
        return False


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Розгортання конфігурацій на всі пристрої топології середньої компанії"
    )
    parser.add_argument("--inventory", default="inventory.yml",
                        help="Шлях до файлу інвентаризації YAML")
    parser.add_argument("--templates", default="templates",
                        help="Директорія з шаблонами Jinja2")
    parser.add_argument("--output-dir", default="configs",
                        help="Директорія для збережених конфігурацій")
    parser.add_argument("--dry-run", action="store_true",
                        help="Лише згенерувати файли, не надсилати на пристрої")
    parser.add_argument("--device", default=None,
                        help="Розгорнути лише для конкретного пристрою (за ім'ям)")
    args = parser.parse_args()

    inventory = load_inventory(args.inventory)
    devices: list[dict] = inventory.get("devices", [])
    vlans: list[dict] = inventory.get("vlans", [])

    os.makedirs(args.output_dir, exist_ok=True)

    env = Environment(
        loader=FileSystemLoader(args.templates),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
    )

    # Глобальний контекст — спільний для всіх шаблонів
    global_ctx = {
        "vlans": vlans,
        "attacker_network": inventory.get("attacker_network", ""),
        "attacker_wildcard": inventory.get("attacker_wildcard", "0.0.0.255"),
        "protected_interface": inventory.get("protected_interface", "GigabitEthernet0/1"),
        "ospf_networks": inventory.get("ospf_networks", []),
    }

    ok_count = 0
    fail_count = 0

    for device in devices:
        if args.device and device["name"] != args.device:
            continue

        role = device.get("role", "")
        dev_type = device.get("device_type", "")

        if dev_type in LINUX_DEVICE_TYPES:
            print(f"[~] Пропускаємо Linux-пристрій {device['name']} (ручне налаштування)")
            continue

        templates_for_role = ROLE_TEMPLATES.get(role, ["base_config.j2"])
        if not templates_for_role:
            print(f"[~] Немає шаблонів для ролі '{role}' ({device['name']}), пропускаємо")
            continue

        print(f"\n[*] Пристрій: {device['name']} | роль: {role} | хост: {device['host']}")

        # Збираємо повну конфігурацію з усіх шаблонів
        full_config = ""
        ctx = {**global_ctx, "device": device}
        for tpl_name in templates_for_role:
            block = render_template(env, tpl_name, ctx)
            if block:
                full_config += f"\n! ---- {tpl_name} ----\n" + block

        # Зберігаємо у файл
        out_path = os.path.join(args.output_dir, f"{device['name']}.cfg")
        with open(out_path, "w") as fh:
            fh.write(full_config)
        print(f"  [+] Конфігурацію збережено: {out_path}")

        if args.dry_run:
            print("  [~] --dry-run: пропускаємо надсилання на пристрій")
            ok_count += 1
            continue

        success = push_to_device(device, full_config)
        if success:
            ok_count += 1
        else:
            fail_count += 1

    print(f"\n{'='*50}")
    print(f"  Результат: {ok_count} успішно, {fail_count} помилок")
    if fail_count:
        sys.exit(1)


if __name__ == "__main__":
    main()
