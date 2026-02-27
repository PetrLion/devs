#!/usr/bin/env python3
"""
security_audit.py — Automated CIS Benchmark security audit for Cisco IOS devices.

Connects to each device in inventory.yml, runs a series of checks and
reports findings with colour-coded severity labels.

Usage:
    python3 security_audit.py [--inventory inventory.yml]
"""

import argparse
import sys
import yaml
from netmiko import ConnectHandler, NetmikoTimeoutException, NetmikoAuthenticationException

# ANSI colour codes
RED = "\033[91m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
RESET = "\033[0m"
BOLD = "\033[1m"


def load_inventory(path: str) -> dict:
    with open(path, "r") as fh:
        return yaml.safe_load(fh)


def check_telnet(output_run_all: str) -> tuple[str, str]:
    """CIS 1.1 — Telnet should be disabled on all VTY lines."""
    if "transport input telnet" in output_run_all.lower():
        return "CRITICAL", "Telnet is ENABLED on VTY lines (transport input telnet)"
    if "transport input ssh" in output_run_all.lower():
        return "PASS", "Only SSH allowed on VTY lines"
    return "WARNING", "VTY transport input not explicitly configured"


def check_ssh_version(output_run_all: str) -> tuple[str, str]:
    """CIS 1.2 — SSH version 2 should be configured."""
    if "ip ssh version 2" in output_run_all.lower():
        return "PASS", "SSH version 2 is configured"
    if "ip ssh version 1" in output_run_all.lower():
        return "CRITICAL", "SSH version 1 is configured — upgrade to version 2"
    return "WARNING", "SSH version not explicitly set to 2"


def check_password_encryption(output_run_all: str) -> tuple[str, str]:
    """CIS 1.3 — Service password-encryption should be enabled."""
    if "service password-encryption" in output_run_all.lower():
        return "PASS", "Password encryption service is enabled"
    return "WARNING", "Password encryption is NOT enabled (service password-encryption missing)"


def check_login_banner(output_run_all: str) -> tuple[str, str]:
    """CIS 1.4 — A login banner (MOTD) should be present."""
    if "banner motd" in output_run_all.lower() or "banner login" in output_run_all.lower():
        return "PASS", "Login banner is configured"
    return "WARNING", "No login banner configured"


def check_acl_on_vty(output_run_all: str) -> tuple[str, str]:
    """CIS 1.5 — VTY lines should have an access-class ACL applied."""
    if "access-class" in output_run_all.lower():
        return "PASS", "ACL (access-class) applied on VTY lines"
    return "WARNING", "No ACL applied on VTY lines"


def check_aaa(output_run_all: str) -> tuple[str, str]:
    """CIS 1.6 — AAA new-model should be enabled."""
    if "aaa new-model" in output_run_all.lower():
        return "PASS", "AAA new-model is enabled"
    return "WARNING", "AAA new-model is NOT enabled"


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
                        "message": f"Cannot connect to device: {exc}"})
    return results


def print_device_report(device: dict, findings: list[dict]) -> None:
    print(f"\n{'='*60}")
    print(f"  Device : {BOLD}{device['name']}{RESET} ({device['host']}) — role: {device.get('role', 'n/a')}")
    print(f"{'='*60}")
    for finding in findings:
        label = severity_label(finding["severity"])
        print(f"  {label} {finding['message']}")


def main() -> None:
    parser = argparse.ArgumentParser(description="CIS Benchmark security audit for Cisco IOS")
    parser.add_argument("--inventory", default="inventory.yml", help="Path to inventory YAML file")
    args = parser.parse_args()

    inventory = load_inventory(args.inventory)
    devices = inventory.get("devices", [])
    print(f"[*] Starting security audit for {len(devices)} device(s) …")

    overall_critical = 0
    for device in devices:
        print(f"[*] Auditing {device['name']} ({device['host']}) …")
        findings = audit_device(device)
        print_device_report(device, findings)
        overall_critical += sum(1 for f in findings if f["severity"] == "CRITICAL")

    print(f"\n{'='*60}")
    if overall_critical:
        print(f"{RED}{BOLD}  Audit complete: {overall_critical} CRITICAL finding(s) detected!{RESET}")
        sys.exit(1)
    else:
        print(f"{GREEN}{BOLD}  Audit complete: no critical findings.{RESET}")


if __name__ == "__main__":
    main()
