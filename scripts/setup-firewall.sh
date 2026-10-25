#!/bin/bash
# Firewall for the home server (ufw), run as root:
#   sudo bash setup-firewall.sh <home-subnet>      e.g. 192.0.2.0/24
#
# Tailscale devices are trusted and may reach everything. Devices on the home
# network may reach only the services meant for them. Nothing else gets in.
# A 5-minute safety timer turns the firewall off again unless it is cancelled,
# so a mistake can never lock you out for good.
set -euo pipefail
LAN="$1"

echo "==> Safety net: firewall turns itself off in 5 minutes unless cancelled"
systemctl stop ufw-safety.timer 2>/dev/null || true
systemd-run --quiet --unit=ufw-safety --on-active=5min /usr/sbin/ufw disable

ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Tailscale: trusted devices, plus forwarding for the subnet router and exit node.
ufw allow in on tailscale0 comment 'Tailscale devices'
ufw route allow in on tailscale0 comment 'Tailscale subnet router and exit node'
ufw allow 41641/udp comment 'Tailscale direct connections'

# Home network: only these services.
ufw allow from "$LAN" to any port 22 proto tcp comment 'SSH'
ufw allow from "$LAN" to any port 53 comment 'AdGuard DNS'
ufw allow from "$LAN" to any port 3000 proto tcp comment 'AdGuard admin'
ufw allow from "$LAN" to any port 443 proto tcp comment 'Wazuh dashboard'
ufw allow from "$LAN" to any port 1514,1515 proto tcp comment 'Wazuh agents'
ufw allow from "$LAN" to any port 5353 proto udp comment 'mDNS (name.local)'

ufw --force enable
ufw status verbose
echo
echo "Test everything, then cancel the safety timer with:"
echo "  sudo systemctl stop ufw-safety.timer"
