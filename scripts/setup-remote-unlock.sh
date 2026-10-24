#!/bin/bash
# Prepare remote disk unlock over Wi-Fi and build a TEST boot image.
# Run on the server as root:
#
#   sudo bash setup-remote-unlock.sh <fixed-address/prefix> <dracut module dir>
#   e.g. sudo bash setup-remote-unlock.sh 192.0.2.10/24 ./dracut/60wifi-unlock
#
# It does not touch the normal boot image. It writes /boot/initrd.img-<kernel>-unlocktest
# so the change can be tried once and the machine falls back if it fails.
set -euo pipefail

ADDRESS="$1"
MODULE_SRC="$2"
KVER="$(uname -r)"
CONF=/etc/wifi-unlock
U="${SUDO_USER:-ian}"

install -d -m 700 "$CONF"

echo "==> Address used during early boot: $ADDRESS"
printf "IFACE_PATTERN='wl*'\nADDRESS='%s'\n" "$ADDRESS" > "$CONF/wifi-unlock.conf"

echo "==> Wi-Fi settings, copied from netplan (key stored hashed, not as the password)"
python3 - "$CONF/wpa_supplicant.conf" <<'PY'
import glob, hashlib, re, sys, yaml
ssid = password = None
for path in sorted(glob.glob("/etc/netplan/*.yaml")):
    doc = yaml.safe_load(open(path)) or {}
    for dev in (doc.get("network", {}).get("wifis") or {}).values():
        for name, ap in (dev.get("access-points") or {}).items():
            ssid = name
            password = (ap.get("auth") or {}).get("password") or ap.get("password")
if not ssid or not password:
    sys.exit("No Wi-Fi network with a password found in /etc/netplan")
# WPA2 turns the password into a 256-bit key with PBKDF2. Storing that key
# instead of the password means the password itself is not in the boot image.
if re.fullmatch(r"[0-9a-fA-F]{64}", password):
    psk = password.lower()
else:
    psk = hashlib.pbkdf2_hmac("sha1", password.encode(), ssid.encode(), 4096, 32).hex()
ssid_line = 'ssid="%s"' % ssid if '"' not in ssid else "ssid=%s" % ssid.encode().hex()
with open(sys.argv[1], "w") as f:
    f.write("ctrl_interface=/run/wpa_supplicant\nnetwork={\n\t%s\n\tpsk=%s\n\tkey_mgmt=WPA-PSK\n}\n" % (ssid_line, psk))
print("    network found and saved")
PY
chmod 600 "$CONF/wpa_supplicant.conf"

echo "==> Host key for the unlock SSH server"
[ -f "$CONF/dropbear_ed25519_host_key" ] || dropbearkey -t ed25519 -f "$CONF/dropbear_ed25519_host_key" >/dev/null
dropbearkey -y -f "$CONF/dropbear_ed25519_host_key" | grep -E "^Fingerprint"

echo "==> Keys allowed to unlock (same keys that can log in as $U)"
: > "$CONF/authorized_keys"
grep -E '^(ssh-|ecdsa-)' "/home/$U/.ssh/authorized_keys" | while read -r key; do
    echo "no-port-forwarding,no-agent-forwarding,no-X11-forwarding $key" >> "$CONF/authorized_keys"
done
chmod 600 "$CONF/authorized_keys"
echo "    $(wc -l < "$CONF/authorized_keys") key(s)"

echo "==> Installing the dracut module"
rm -rf /usr/lib/dracut/modules.d/60wifi-unlock
cp -r "$MODULE_SRC" /usr/lib/dracut/modules.d/60wifi-unlock
chmod 755 /usr/lib/dracut/modules.d/60wifi-unlock/*.sh

echo "==> Building the TEST boot image (the normal one is left alone)"
dracut --force --add wifi-unlock "/boot/initrd.img-$KVER-unlocktest" "$KVER"
ls -l "/boot/initrd.img-$KVER-unlocktest"
