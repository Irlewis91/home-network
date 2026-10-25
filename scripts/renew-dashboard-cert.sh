#!/bin/bash
# Renew the Tailscale (Let's Encrypt) certificate used by the Wazuh dashboard.
# tailscale cert only fetches a new one when the current one is close to expiring.
set -e
C=/etc/wazuh-dashboard/certs
FQDN=$(tailscale status --json | python3 -c "import json,sys; print(json.load(sys.stdin)[\"Self\"][\"DNSName\"].rstrip(\".\"))")
before=$(sha256sum $C/tailscale.crt | cut -d" " -f1)
chmod 600 $C/tailscale.crt $C/tailscale.key
tailscale cert --cert-file $C/tailscale.crt --key-file $C/tailscale.key "$FQDN"
chown wazuh-dashboard:wazuh-dashboard $C/tailscale.crt $C/tailscale.key
chmod 400 $C/tailscale.crt $C/tailscale.key
after=$(sha256sum $C/tailscale.crt | cut -d" " -f1)
[ "$before" != "$after" ] && systemctl restart wazuh-dashboard && echo "renewed and restarted" || echo "still valid"
