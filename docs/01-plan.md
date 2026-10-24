# 1. The plan

## Starting point

I asked an AI assistant how to turn a 2015 MacBook Air into a home server. Its plan was mostly sound: wipe macOS, install Ubuntu, run services in Docker, and manage it from my main Mac over SSH. A few parts needed fixing, so this is the corrected version.

## What each device does

| Device | Job |
|---|---|
| **2015 MacBook Air** | The main server. Runs Linux and Docker around the clock. |
| **2TB external drive** | Plugged into the server. Holds backups, media and container data. |
| **Rooted Android phone** | A second, independent node. If the server is down, it can still answer DNS and send an alert. |
| **M3 MacBook Air** | Where I work. Every server step is done from here over SSH. |

## Why Linux and not macOS

- Apple no longer sends security updates for macOS on this model. Ubuntu LTS gets updates for years.
- Docker on macOS runs inside a virtual machine that eats RAM. On Linux it runs directly, which matters with only 8 GB.
- With no desktop running, Ubuntu idles at a few hundred MB of RAM.

## Why Ubuntu Desktop and not Ubuntu Server

The Air's built-in Wi-Fi chip is a Broadcom BCM4360. Its Linux driver is not open source, so the Ubuntu **Server** installer does not include it, and the machine would have no network after install. The Ubuntu **Desktop** installer can add it when you tick "Install third-party software." After install, the desktop gets switched off so it runs like a server.

Backup plan: a USB Wi-Fi adapter with a Realtek RTL8812BU chip, which Linux supports out of the box. See [the hardware check](04-hardware-check.md).

## Corrections to the original plan

1. **The battery is not a free UPS.** It is about 10 years old. Old lithium batteries kept on the charger all the time can swell. Check its health first and look for a bulging case every few months.
2. **Keep production off it.** The original plan suggested connecting live websites to databases on this laptop. A home laptop on home internet is fine for testing and tools, not for anything customers depend on.
3. **No local AI models.** This CPU cannot run them in any useful way. Scripts that call AI services over the internet are fine.
4. **Storage is small.** The internal SSD is 128 GB. That is why the 2TB drive matters.

## Installer media

You need something to start the Ubuntu installer from. Options I considered:

| Option | Notes |
|---|---|
| USB stick (16 GB or more) | Easiest. Get one with both USB-C and USB-A plugs if your main Mac only has USB-C. |
| SD card | The 13-inch Air has an SD slot and can start up from it. |
| **External drive** | Works the same as a USB stick, but writing the installer erases it. **Chosen:** my 2TB drive is empty, so it becomes the installer first, then gets reformatted as storage. |
| Partition on the internal disk | Free but fiddly. |

Next: [connect with an SSH key](02-ssh-key.md).
