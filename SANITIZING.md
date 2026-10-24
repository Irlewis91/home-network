# How sensitive info is kept out of this repo

This repo is public, so anything that identifies my network, devices or accounts is replaced before it is committed.

## What gets replaced

| Placeholder | What it stands for |
|---|---|
| `<server-ip>` | Local IP address of the old MacBook Air |
| `<phone-ip>` | Local IP address of the Android phone |
| `<control-mac-ip>` | Local IP address of the M3 MacBook Air |
| `<server-user>` | Login name on the server |
| `<termux-user>` | Termux user on the phone |
| `<server-host>`, `<control-mac>` | Computer host names (they contain my name) |
| `<server-computer-name>`, `<control-mac-name>` | Computer display names |
| `<phone-serial>` | Phone serial number |
| `<wifi-name>` | Wi-Fi network name |
| `<email>` | Email addresses |
| `<public-ipv6>`, `<public-ipv6-prefix>` | Public IPv6 addresses (these can reveal location) |
| `<mac-address>` | Hardware network addresses |
| `<private-ip>` | Any other local IP address |

Things that are **not** secret and stay in: hardware models, chip IDs, software versions, firmware build numbers and checksums, port numbers.

Never stored here at all: private SSH keys, passwords, API keys, tokens, `.env` files.

## How it is enforced

1. **`.sensitive-map`** lists the real values next to their placeholders, one per line, tab separated. It is in `.gitignore`, so it never leaves my computer.
2. **`scripts/sanitize.py`** replaces everything in that map, plus generic patterns (local IPs, public IPv6, MAC addresses, private keys, tokens), in any text file.
3. **`scripts/term-screenshot.py`** runs the sanitizer before drawing a screenshot, so redacted values show up highlighted, like <code>&lt;server-ip&gt;</code>.
4. **`.githooks/pre-commit`** runs `scripts/check-sensitive.sh` on every commit and blocks it if a real value or a generic pattern is found. It never prints the matched value, only the file and line.
5. **Images** cannot be searched as text, so every screenshot is checked by eye before it is committed. Raw captures stay in `screenshots/raw/`, which is gitignored.

## Using this in your own copy

```bash
git config core.hooksPath .githooks
printf '%s\t%s\n' "your-real-server-ip" "<server-ip>" >> .sensitive-map
scripts/check-sensitive.sh --all
```
