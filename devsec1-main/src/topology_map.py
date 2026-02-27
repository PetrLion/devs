#!/usr/bin/env python3
"""
topology_map.py — Модуль візуалізації мережевої топології.

Підключається до кожного пристрою з inventory.yml через SSH (netmiko),
збирає інформацію про сусідів CDP/LLDP, будує граф та
зберігає інтерактивну HTML-карту за допомогою PyVis.

Використання:
    python3 topology_map.py [--inventory inventory.yml] [--output topology.html]
"""

import argparse
import sys
import yaml
from netmiko import ConnectHandler, NetmikoTimeoutException, NetmikoAuthenticationException
from pyvis.network import Network


def load_inventory(path: str) -> dict:
    with open(path, "r") as fh:
        return yaml.safe_load(fh)


def collect_lldp_neighbors(device: dict) -> list[dict]:
    """Підключитись до пристрою Cisco IOS та повернути розпізнані записи сусідів LLDP."""
    conn_params = {
        "device_type": device["device_type"],
        "host": device["host"],
        "username": device["username"],
        "password": device["password"],
        "timeout": 10,
    }
    neighbors = []
    try:
        with ConnectHandler(**conn_params) as conn:
            output = conn.send_command("show lldp neighbors detail", use_textfsm=True)
            if isinstance(output, list):
                for entry in output:
                    neighbors.append({
                        "local_port": entry.get("local_interface", ""),
                        "remote_host": entry.get("neighbor", ""),
                        "remote_port": entry.get("neighbor_interface", ""),
                    })
            else:
                # Запасний варіант: спробувати CDP
                output = conn.send_command("show cdp neighbors detail", use_textfsm=True)
                if isinstance(output, list):
                    for entry in output:
                        neighbors.append({
                            "local_port": entry.get("local_port", ""),
                            "remote_host": entry.get("destination_host", ""),
                            "remote_port": entry.get("remote_port", ""),
                        })
    except (NetmikoTimeoutException, NetmikoAuthenticationException) as exc:
        print(f"  [ПОПЕРЕДЖЕННЯ] Неможливо підключитись до {device['name']} ({device['host']}): {exc}",
              file=sys.stderr)
    return neighbors


def build_topology_graph(devices: list[dict]) -> Network:
    net = Network(
        height="600px",
        width="100%",
        bgcolor="#1e1e2e",
        font_color="#cdd6f4",
        notebook=False,
    )
    net.set_options("""
    {
      "physics": {"enabled": true},
      "nodes": {"shape": "box", "font": {"size": 14}},
      "edges": {"arrows": {"to": {"enabled": false}}}
    }
    """)

    role_colors = {
        "main": "#89b4fa",
        "user": "#a6e3a1",
        "attacker": "#f38ba8",
    }

    for device in devices:
        color = role_colors.get(device.get("role", ""), "#cdd6f4")
        net.add_node(
            device["name"],
            label=f"{device['name']}\n{device['host']}",
            color=color,
            title=f"Роль: {device.get('role', 'н/д')}\nХост: {device['host']}",
        )

    added_edges: set[frozenset] = set()
    for device in devices:
        print(f"  Опитування {device['name']} ({device['host']}) …")
        neighbors = collect_lldp_neighbors(device)
        for nbr in neighbors:
            edge = frozenset([device["name"], nbr["remote_host"]])
            if edge not in added_edges:
                label = f"{nbr['local_port']} ↔ {nbr['remote_port']}"
                net.add_edge(device["name"], nbr["remote_host"], title=label, label=label)
                added_edges.add(edge)

    return net


def main() -> None:
    parser = argparse.ArgumentParser(description="Генерація інтерактивної карти мережевої топології")
    parser.add_argument("--inventory", default="inventory.yml", help="Шлях до файлу інвентаризації YAML")
    parser.add_argument("--output", default="topology.html", help="Вихідний HTML-файл")
    args = parser.parse_args()

    inventory = load_inventory(args.inventory)
    devices = inventory.get("devices", [])
    print(f"[*] Завантажено {len(devices)} пристрій(ів) з {args.inventory}")

    graph = build_topology_graph(devices)
    graph.save_graph(args.output)
    print(f"[+] Карту топології збережено до {args.output}")


if __name__ == "__main__":
    main()
