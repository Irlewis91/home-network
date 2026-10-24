#!/bin/bash
# Write an Ubuntu installer ISO to an external drive from macOS.
# THIS ERASES THE WHOLE TARGET DRIVE.
#
# Usage (as root):
#   sudo bash write-installer-macos.sh <iso> <sha256> "<media name>" <size in bytes>
#
# The target is found by its media name AND exact size AND being external.
# If no drive matches all three, nothing is written.
set -euo pipefail
# shasum is a perl script and warns when the SSH session passes a locale macOS
# does not have (for example C.UTF-8). Plain C avoids the noise.
export LC_ALL=C

ISO="$1"
SHA="$2"
WANT_MEDIA="$3"
WANT_BYTES="$4"

[ "$(id -u)" = 0 ] || { echo "Run this with sudo."; exit 1; }
[ -f "$ISO" ] || { echo "Installer file not found: $ISO"; exit 1; }

echo "1/5  Checking the installer file (takes about a minute)..."
got=$(shasum -a 256 "$ISO" | cut -d' ' -f1)
if [ "$got" != "$SHA" ]; then
  echo "     Checksum does NOT match. The download is damaged. Nothing was written."
  exit 1
fi
echo "     Checksum matches."

echo "2/5  Looking for the target drive..."
disk=""
for d in $(diskutil list external physical | awk '/^\/dev\/disk/ {print $1}'); do
  info=$(diskutil info "$d")
  media=$(sed -n 's/^ *Device \/ Media Name: *//p' <<< "$info")
  bytes=$(sed -n 's/.*Disk Size:.*(\([0-9]*\) Bytes).*/\1/p' <<< "$info")
  where=$(sed -n 's/^ *Device Location: *//p' <<< "$info")
  if [ "$media" = "$WANT_MEDIA" ] && [ "$bytes" = "$WANT_BYTES" ] && [ "$where" = "External" ]; then
    [ -n "$disk" ] && { echo "     More than one drive matches. Stopping."; exit 1; }
    disk="$d"
  fi
done
[ -n "$disk" ] || { echo "     No external drive named '$WANT_MEDIA' with $WANT_BYTES bytes. Nothing was written."; exit 1; }
echo "     Found $WANT_MEDIA at $disk."

echo "3/5  Unmounting $disk..."
diskutil unmountDisk force "$disk"

size=$(stat -f%z "$ISO")
echo "4/5  Writing $((size / 1048576)) MB to $disk. This erases the drive. Takes roughly 3 to 10 minutes..."
dd if="$ISO" of="/dev/r${disk#/dev/}" bs=4m status=progress
sync

echo "5/5  Reading it back to confirm the write (another few minutes)..."
diskutil unmountDisk force "$disk" >/dev/null 2>&1 || true
back=$(head -c "$size" "$disk" | shasum -a 256 | cut -d' ' -f1)
if [ "$back" = "$SHA" ]; then
  echo "     Read-back matches the installer. Done."
  diskutil eject "$disk"
  echo "The drive is ready. Restart this Mac holding Option to start the installer."
else
  echo "     Read-back does NOT match. Run this script again."
  exit 1
fi
