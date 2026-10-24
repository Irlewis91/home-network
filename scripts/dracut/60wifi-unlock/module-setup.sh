#!/bin/bash
# dracut module: unlock an encrypted root disk over SSH, on Wi-Fi.
#
# During early boot it brings up a USB Wi-Fi adapter, gives it a fixed
# address and starts dropbear on port 2222. Logging in runs only
# systemd-tty-ask-password-agent, which asks for the disk passphrase.
#
# Files it expects on the host (created by scripts/setup-remote-unlock.sh):
#   /etc/wifi-unlock/wifi-unlock.conf       interface pattern and address
#   /etc/wifi-unlock/wpa_supplicant.conf    Wi-Fi network (hashed key)
#   /etc/wifi-unlock/authorized_keys        who may unlock
#   /etc/wifi-unlock/dropbear_ed25519_host_key

check() {
    require_binaries dropbear wpa_supplicant ip || return 1
    [ -f /etc/wifi-unlock/wpa_supplicant.conf ] || return 1
    # Only when asked for, never picked automatically.
    return 255
}

depends() {
    echo systemd systemd-ask-password crypt
}

installkernel() {
    # USB Wi-Fi adapter (Realtek RTL8812BU) and the wireless stack.
    instmods rtw88_8822bu rtw88_usb rtw88_8822b rtw88_core mac80211 cfg80211
}

install() {
    inst_multiple dropbear wpa_supplicant wpa_cli ip sleep grep basename cat
    inst_multiple -o /lib/firmware/regulatory.db /lib/firmware/regulatory.db.p7s

    inst_simple /etc/wifi-unlock/wifi-unlock.conf /etc/wifi-unlock/wifi-unlock.conf
    inst_simple /etc/wifi-unlock/wpa_supplicant.conf /etc/wifi-unlock/wpa_supplicant.conf
    inst_simple /etc/wifi-unlock/dropbear_ed25519_host_key /etc/wifi-unlock/dropbear_ed25519_host_key
    inst_simple /etc/wifi-unlock/authorized_keys /root/.ssh/authorized_keys
    chmod 700 "$initdir/root/.ssh"
    chmod 600 "$initdir/root/.ssh/authorized_keys"

    # dropbear refuses users whose shell is not listed here.
    grep -q '^root:' "$initdir/etc/passwd" 2>/dev/null || echo 'root:x:0:0:root:/root:/bin/sh' >> "$initdir/etc/passwd"
    printf '/bin/sh\n/bin/bash\n' >> "$initdir/etc/shells"

    inst_script "$moddir/wifi-unlock-net.sh" /usr/sbin/wifi-unlock-net
    inst_simple "$moddir/wifi-unlock-net.service" "$systemdsystemunitdir/wifi-unlock-net.service"
    inst_simple "$moddir/wifi-unlock-ssh.service" "$systemdsystemunitdir/wifi-unlock-ssh.service"
    $SYSTEMCTL -q --root "$initdir" enable wifi-unlock-net.service wifi-unlock-ssh.service
}
