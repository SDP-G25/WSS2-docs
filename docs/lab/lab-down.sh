#!/usr/bin/env bash
# Tear down the Manara test AP and restore the laptop to normal.
# Usage: sudo ./lab-down.sh [wlan-iface] [uplink-iface]
set -euo pipefail

WLAN="${1:-wlan1}"
UPLINK="${2:-eth0}"

if [[ $EUID -ne 0 ]]; then echo "Run with sudo." >&2; exit 1; fi

echo "[*] Stopping dnsmasq"
[[ -f /tmp/manara-dnsmasq.pid ]] && kill "$(cat /tmp/manara-dnsmasq.pid)" 2>/dev/null || true
rm -f /tmp/manara-dnsmasq.pid

echo "[*] Removing internet-sharing rules"
iptables -t nat -D POSTROUTING -o "$UPLINK" -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i "$WLAN" -o "$UPLINK" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i "$UPLINK" -o "$WLAN" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

echo "[*] Restoring $WLAN to NetworkManager"
ip addr flush dev "$WLAN" || true
nmcli device set "$WLAN" managed yes || true

echo "[*] Done. (hostapd stops when you Ctrl+C its terminal.)"
