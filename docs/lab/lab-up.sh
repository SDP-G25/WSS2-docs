#!/usr/bin/env bash
# Bring up the Manara test AP on Parrot/Linux.
# Usage: sudo ./lab-up.sh [wlan-iface] [uplink-iface]
#   wlan-iface   USB AP card         (default wlan1)
#   uplink-iface interface with net  (default eth0)
# Pre-connection rule tests don't need internet; connected-network tests do.
set -euo pipefail

WLAN="${1:-wlan1}"
UPLINK="${2:-eth0}"
DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $EUID -ne 0 ]]; then echo "Run with sudo." >&2; exit 1; fi

echo "[*] Releasing $WLAN from NetworkManager"
nmcli device set "$WLAN" managed no || true
iw reg set QA || true

echo "[*] Addressing $WLAN -> 192.168.50.1/24"
ip addr flush dev "$WLAN"
ip addr add 192.168.50.1/24 dev "$WLAN"
ip link set "$WLAN" up

echo "[*] Enabling internet sharing via $UPLINK"
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -C POSTROUTING -o "$UPLINK" -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o "$UPLINK" -j MASQUERADE
iptables -C FORWARD -i "$WLAN" -o "$UPLINK" -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i "$WLAN" -o "$UPLINK" -j ACCEPT
iptables -C FORWARD -i "$UPLINK" -o "$WLAN" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i "$UPLINK" -o "$WLAN" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

echo "[*] Starting dnsmasq (background)"
dnsmasq -C "$DIR/dnsmasq.conf" --pid-file=/tmp/manara-dnsmasq.pid

echo "[*] Starting hostapd (foreground — Ctrl+C to stop, then run lab-down.sh)"
echo "    Interface: $WLAN   Uplink: $UPLINK"
exec hostapd "$DIR/hostapd.conf"
