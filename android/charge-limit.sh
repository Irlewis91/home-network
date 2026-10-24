#!/system/bin/sh
# Keep the battery between 45% and 50% while the phone stays plugged in.
#
# Install (rooted with Magisk): copy to /data/adb/service.d/charge-limit.sh
# and chmod 755. Magisk runs everything in service.d as root at every boot.
#
# How it pauses charging on this phone (moto g stylus 5G 2022): setting the
# charger's input current limit to 0 cuts power from the wall, so the phone
# runs on its battery. The phone still reports "Charging", which is why
# tools that wait for a "Not charging" status (like ACC) reject this method.
STOP_AT=50
START_AT=45
LIMIT=/sys/class/power_supply/charger/input_current_limit
CAPACITY=/sys/class/power_supply/battery/capacity
NORMAL=3000000
LOG=/data/local/tmp/charge-limit.log

# Wait for the system to finish booting.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done

echo "$(date '+%F %T') started: stop at $STOP_AT%, start at $START_AT%" >> "$LOG"
state=""
while true; do
    level=$(cat "$CAPACITY")
    if [ "$level" -ge "$STOP_AT" ]; then
        want=paused
    elif [ "$level" -le "$START_AT" ]; then
        want=charging
    else
        want=${state:-charging}
    fi
    # Write every cycle: the driver can reset the limit when the cable is replugged.
    if [ "$want" = paused ]; then echo 0 > "$LIMIT"; else echo "$NORMAL" > "$LIMIT"; fi
    if [ "$want" != "$state" ]; then
        echo "$(date '+%F %T') $level%: $want" >> "$LOG"
        state=$want
    fi
    sleep 60
done
