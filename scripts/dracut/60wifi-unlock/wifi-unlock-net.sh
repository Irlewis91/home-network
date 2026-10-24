#!/bin/sh
# Early-boot Wi-Fi: find the adapter, join the network, set a fixed address.
# start: called by wifi-unlock-net.service
# stop:  called before switching to the real system, so NetworkManager
#        takes over a clean interface
. /etc/wifi-unlock/wifi-unlock.conf   # IFACE_PATTERN, ADDRESS (for example 192.0.2.10/24)

iface() {
    for n in /sys/class/net/$IFACE_PATTERN; do
        [ -e "$n" ] && { basename "$n"; return 0; }
    done
    return 1
}

case "$1" in
start)
    i=0
    until IF=$(iface); do
        i=$((i + 1)); [ $i -ge 60 ] && { echo "wifi-unlock: no Wi-Fi interface found"; exit 1; }
        sleep 1
    done
    echo "wifi-unlock: using $IF"
    ip link set "$IF" up
    wpa_supplicant -B -i "$IF" -c /etc/wifi-unlock/wpa_supplicant.conf -P /run/wifi-unlock-wpa.pid
    i=0
    until wpa_cli -i "$IF" status 2>/dev/null | grep -q '^wpa_state=COMPLETED'; do
        i=$((i + 1)); [ $i -ge 60 ] && { echo "wifi-unlock: could not join Wi-Fi"; exit 1; }
        sleep 1
    done
    ip addr add "$ADDRESS" dev "$IF"
    echo "wifi-unlock: $IF is up at $ADDRESS"
    ;;
stop)
    IF=$(iface) || exit 0
    [ -f /run/wifi-unlock-wpa.pid ] && kill "$(cat /run/wifi-unlock-wpa.pid)" 2>/dev/null
    ip addr flush dev "$IF" 2>/dev/null
    ip link set "$IF" down 2>/dev/null
    ;;
esac
exit 0
