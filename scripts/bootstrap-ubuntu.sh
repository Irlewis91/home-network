#!/bin/bash
# First-boot setup for a fresh Ubuntu Desktop install that will run as a
# headless server. Typed once at the machine:
#
#   wget -qO- <control-mac-ip>:8000/go | sudo bash
#
# The control Mac serves this file with its own public key and address filled
# in (CONTROL_KEY and CONTROL_IP below). After it runs, everything else is
# done over SSH.
set -euo pipefail

CONTROL_KEY="${CONTROL_KEY:-__CONTROL_KEY__}"
CONTROL_IP="${CONTROL_IP:-__CONTROL_IP__}"
U="${SUDO_USER:-$(logname)}"
H="$(getent passwd "$U" | cut -d: -f6)"

echo "==> Installing the SSH server"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y -q openssh-server

echo "==> Allowing the control Mac's key for $U"
install -d -m 700 -o "$U" -g "$U" "$H/.ssh"
touch "$H/.ssh/authorized_keys"
grep -qF "$CONTROL_KEY" "$H/.ssh/authorized_keys" || echo "$CONTROL_KEY" >> "$H/.ssh/authorized_keys"
chown "$U:$U" "$H/.ssh/authorized_keys"
chmod 600 "$H/.ssh/authorized_keys"

echo "==> Key-only SSH (no password logins)"
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n' > /etc/ssh/sshd_config.d/10-key-only.conf
systemctl enable --now ssh
# Newer Ubuntu starts sshd on demand through ssh.socket, so the service may
# not be running yet. Either way the next connection reads the new settings.
systemctl reload ssh 2>/dev/null || true

echo "==> sudo without a password, so the control Mac can manage this machine"
echo "$U ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$U-nopasswd"
chmod 440 "/etc/sudoers.d/90-$U-nopasswd"
visudo -cf "/etc/sudoers.d/90-$U-nopasswd" >/dev/null || { rm -f "/etc/sudoers.d/90-$U-nopasswd"; echo "sudoers check failed, skipped"; }

echo "==> Server power settings: ignore the lid, never sleep"
mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\nHandleLidSwitchDocked=ignore\n' > /etc/systemd/logind.conf.d/10-server-lid.conf
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null
# Reload logind's settings without ending the desktop session.
systemctl kill -s HUP systemd-logind || true

IP="$(hostname -I | awk '{print $1}')"
wget -q -O /dev/null "http://$CONTROL_IP:8000/done?ip=$IP&user=$U&host=$(hostname)" || true

echo
echo "All set. This machine is at $IP and can be managed over SSH."
echo "You can walk away. Plug the external drive back in if it is unplugged."
