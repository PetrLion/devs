#!/usr/bin/env python3
"""
acl_generator.py — Jinja2-based ACL configuration generator for Cisco IOS.

Reads attacker/network data from inventory.yml, renders the Jinja2 template
in templates/acl_block.j2 and saves the result to configs/<device_name>_acl.cfg.
Optionally pushes the generated config to the device via SSH (--apply flag).

Usage:
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
    """Push the generated config lines to the device via netmiko."""
    try:
        from netmiko import ConnectHandler, NetmikoTimeoutException, NetmikoAuthenticationException
    except ImportError:
        print("  [ERROR] netmiko is not installed. Run: pip install netmiko", file=sys.stderr)
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
            print(f"  [+] Config pushed to {device['name']}:\n{output}")
    except Exception as exc:
        print(f"  [ERROR] Failed to push config to {device['name']}: {exc}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Cisco IOS ACL configs from Jinja2 templates")
    parser.add_argument("--inventory", default="inventory.yml", help="Path to inventory YAML file")
    parser.add_argument("--templates", default="templates", help="Directory containing Jinja2 templates")
    parser.add_argument("--output-dir", default="configs", help="Directory for generated config files")
    parser.add_argument("--apply", action="store_true", help="Push generated config to devices via SSH")
    args = parser.parse_args()

    inventory = load_inventory(args.inventory)
    devices = inventory.get("devices", [])

    context = {
        "attacker_network": inventory.get("attacker_network", "192.168.1.3"),
        "attacker_wildcard": inventory.get("attacker_wildcard", "0.0.0.0"),
        "protected_interface": inventory.get("protected_interface", "GigabitEthernet0/0"),
    }

    os.makedirs(args.output_dir, exist_ok=True)

    print(f"[*] Rendering ACL template for {len(devices)} device(s) …")
    config_text = render_acl(args.templates, context)

    for device in devices:
        if device.get("role") == "main":
            out_path = os.path.join(args.output_dir, f"{device['name']}_acl.cfg")
            with open(out_path, "w") as fh:
                fh.write(config_text)
            print(f"[+] Config saved: {out_path}")

            if args.apply:
                print(f"[*] Applying config to {device['name']} ({device['host']}) …")
                apply_config(device, config_text)

    print("[+] ACL generation complete.")


if __name__ == "__main__":
    main()
