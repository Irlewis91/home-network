#!/system/bin/sh
# Start AdGuard Home as root at every boot, without opening Termux.
#
# Install (rooted with Magisk): copy to /data/adb/service.d/adguardhome.sh
# and chmod 755. AdGuard Home itself lives in Termux's home folder.
# Root is needed to listen on DNS port 53.
DIR=/data/data/com.termux/files/home/adguard/AdGuardHome
LOG=/data/local/tmp/adguardhome.log

# AdGuard Home is a Linux program and looks for trusted certificates in
# /etc/ssl, which Android does not have. Without this, encrypted upstream DNS
# fails with "certificate signed by unknown authority". Android 14 and newer
# keep them under /apex, Android 13 and older under /system.
export SSL_CERT_DIR="/apex/com.android.conscrypt/cacerts:/system/etc/security/cacerts"

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done

# Restart it if it ever stops.
while true; do
    echo "$(date '+%F %T') starting AdGuard Home" >> "$LOG"
    "$DIR/AdGuardHome" -w "$DIR" --no-check-update >> "$LOG" 2>&1
    sleep 10
done
