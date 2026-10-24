#!/usr/bin/env python3
"""Replace sensitive values with placeholders before anything goes public.

Reads real values from .sensitive-map (tab separated: real value, placeholder).
That file is gitignored and never leaves this computer. Generic patterns
(MAC addresses, private IPs, public IPv6, keys) are caught even if they are
not in the map.

Usage:
  python3 scripts/sanitize.py < raw.txt > clean.txt
  python3 scripts/sanitize.py file1 file2   (rewrites the files in place)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAP_FILE = ROOT / ".sensitive-map"

GENERIC = [
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.S), "<private-key-removed>"),
    (re.compile(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b"), "<mac-address>"),
    (re.compile(r"\b192\.168\.\d{1,3}\.\d{1,3}\b"), "<private-ip>"),
    (re.compile(r"\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"), "<private-ip>"),
    (re.compile(r"\b2[0-9a-f]{3}:[0-9a-f]{1,4}:[0-9a-f:]+\b", re.I), "<public-ipv6>"),
    (re.compile(r"\bfe80:[0-9a-f:]+\b", re.I), "<link-local-ipv6>"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"), "<token-removed>"),
    (re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"), "<token-removed>"),
]


def load_map():
    pairs = []
    if MAP_FILE.exists():
        for line in MAP_FILE.read_text(encoding="utf-8").splitlines():
            if "\t" in line:
                real, placeholder = line.split("\t", 1)
                if real:
                    pairs.append((real, placeholder))
    # Longest first, so "host-2.local" is replaced before "host".
    return sorted(pairs, key=lambda p: len(p[0]), reverse=True)


def sanitize(text, pairs):
    for real, placeholder in pairs:
        text = text.replace(real, placeholder)
    for pattern, placeholder in GENERIC:
        text = pattern.sub(placeholder, text)
    return text


def main():
    pairs = load_map()
    if len(sys.argv) == 1:
        sys.stdout.write(sanitize(sys.stdin.read(), pairs))
        return
    for name in sys.argv[1:]:
        path = pathlib.Path(name)
        path.write_text(sanitize(path.read_text(encoding="utf-8"), pairs), encoding="utf-8")


if __name__ == "__main__":
    main()
