# Android phone as a Linux node

An old phone makes a good second node: it uses almost no power, has a built-in battery, and keeps running if the main server goes down. This one is rooted and runs a full Debian userland through Termux.

This was set up before the rest of the repo, so this page is a cleaned-up record of what was done rather than a live walkthrough. No screenshots yet.

## Device

| Item | Value |
|---|---|
| Phone | Motorola moto g stylus 5G (2022), model XT2215-4, codename `milanf` |
| Android | 13, build T2SDS33.75-38-1-3-26 (T-Mobile software channel) |
| Kernel | 5.4.274 (December 2024) |
| Bootloader | Unlocked, active slot **a** |
| Root | Magisk v30.7, patched stock boot image on `boot_a` |
| Network | Wi-Fi, fixed address `<phone-ip>` reserved on the router |

## Planned role in the network

- **Backup DNS.** A second ad-blocking DNS server, so the internet keeps working if the main server is rebooting.
- **Watchdog.** Pings the server every few minutes and raises an alert if it disappears.
- **Alerts.** Can speak a message out loud, flash its torch or send a notification.

## Connecting

From the control Mac. Password login is off, key only:

```bash
ssh -p 8022 <termux-user>@<phone-ip>
```

Termux runs its SSH server on port **8022**, not 22, because Android apps cannot use ports below 1024. The username is the Android app user Termux runs as; `whoami` inside Termux shows it.

To let another computer in, add its **public** key to `~/.ssh/authorized_keys` on the phone.

`adb` and `fastboot` on the Mac come from Android SDK Platform Tools.

## What is installed

- **Termux** v0.118.3 and **Termux:API** v0.53.0, from the official GitHub releases (not the outdated Play Store version).
- Termux packages: `proot-distro`, `openssh`, `git`, `tsu`, `cronie`, `termux-api`, `termux-services`, `python`.
- A **Debian 13** container: `proot-distro login debian`.
- `sshd` (port 8022) and `crond` run as Termux services. Check them with:

  ```bash
  SVDIR=$PREFIX/var/service sv status sshd crond
  ```

- After the phone reboots, open the Termux app once to start them again, or install **Termux:Boot** to make that automatic.

## Scripts and hardware access

- `~/scripts/verify_node.py` pings an address and prints Online or Offline:

  ```bash
  python ~/scripts/verify_node.py <server-ip>
  ```

- Hardware commands that work: `termux-battery-status`, `termux-torch on`, `termux-torch off`, `termux-tts-speak "message"`.
- Scheduled jobs: `crontab -e`.

## Android settings that had to change

Android 13 kills background processes it thinks are runaway ("phantom process killer"), which stops Termux services. There is no menu toggle on 13, so it is turned off over `adb`:

```bash
adb shell device_config set_sync_disabled_for_tests persistent
adb shell device_config put activity_manager max_phantom_processes 2147483647
adb shell settings put global settings_enable_monitor_phantom_procs false
```

Termux and Termux:API are also excluded from battery optimization:

```bash
adb shell dumpsys deviceidle whitelist +com.termux +com.termux.api
```

## Root

- `su` works from Termux once Termux is allowed in **Magisk > Superuser**. SELinux stays Enforcing.
- `tsu` gives a root shell that keeps Termux tools on the path. It does not take `-c`; use `su -c "command"` for one-off commands.
- tsu v8 does not know where Magisk puts `su`. It was patched to also look in `/debug_ramdisk/su` and `/product/bin/su`. A `pkg upgrade` of tsu undoes this; reapply with:

  ```bash
  sed -i 's|^SU_BINARY_SEARCH=("/system/xbin/su" "/system/bin/su")|SU_BINARY_SEARCH=("/system/xbin/su" "/system/bin/su" "/debug_ramdisk/su" "/product/bin/su")|' $PREFIX/bin/tsu
  ```

**Things to know before rooting a phone like this:**

- Rooted phones fail Play Integrity, so banking apps, tap to pay and some streaming apps may stop working.
- Anyone who can SSH in as the Termux user can become root. Keep the SSH key private and password login off.
- A phone on the charger 24/7 wears its battery. This one is held at 45 to 50% (see below).

## Fixing Wi-Fi that would not scan

After an earlier rooting attempt, Wi-Fi would not turn on. The phone was running an old June 2022 kernel on top of December 2024 firmware, so the Wi-Fi driver (`qca_cld3_wlan.ko`) could not load and `wlan0` never appeared.

Fix: flash the stock `boot`, `vendor_boot` and `dtbo` images from the firmware that matches the installed build, to slot a. No data was erased. Then patch the matching stock boot image with Magisk again.

## Firmware and recovery

- Firmware: `XT2215-4_MILANF_TMO_13_T2SDS33.75-38-1-3-26_subsidy-TMO_UNI_RSU_QCOM_regulatory-DEFAULT_cid50_CFC.xml.zip` (4.64 GB), from the lolinet mirror: https://mirrors-obs-1.lolinet.com/firmware/lenomola/2022/milanf/official/TMO/
- MD5 checksums, from the firmware's `flashfile.xml`:

| Image | MD5 |
|---|---|
| boot.img (stock) | 70b165b5f7457ef48dad14b8be008c72 |
| vendor_boot.img | b2644af8a2bfad68061e0b869279fe7b |
| dtbo.img | 0643afb2abc97d03b8497045dc0abfa4 |
| Magisk-patched boot | 7eb5979b4c82c1ab511383ab3c306d5e |

- Magisk: `Magisk-v30.7.apk` from https://github.com/topjohnwu/Magisk/releases, SHA-256 `e0d32d2123532860f97123d927b1bb86c4e08e6fd8a48bfc6b5bee0afae9ebd5`.

To remove root, or if the phone ever fails to boot, flash the stock boot image:

```bash
adb reboot bootloader
fastboot getvar current-slot
fastboot flash boot_a boot.img
fastboot reboot
```

If that is not enough, flash the full firmware from the same build. Its full flash steps erase user data.

## If the phone loses internet

Packages can still be installed over USB: run a local proxy on the Mac, forward it with `adb reverse tcp:8118 tcp:8118`, and point the package manager at `http://127.0.0.1:8118`. The phone's clock must be right or HTTPS fails.

## Running on it now

- **AdGuard Home**, the network's ad blocker, started at boot by Magisk: [guide 10](../docs/10-adguard-and-battery.md)
- **Battery held at 45 to 50%** by [`charge-limit.sh`](charge-limit.sh). ACC did not work on this phone; the guide explains why.
- **Tailscale** (Android app), with "Use Tailscale subnets" turned off

## Not done yet

- Termux:Boot, so SSH starts after a reboot without opening Termux
- A watchdog that alerts if the server goes offline
