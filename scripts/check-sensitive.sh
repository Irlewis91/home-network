#!/usr/bin/env bash
# Block commits that contain sensitive values.
#
#   scripts/check-sensitive.sh          check staged files (used by the pre-commit hook)
#   scripts/check-sensitive.sh --all    check every tracked and untracked file
#
# Real values come from .sensitive-map (gitignored). Images cannot be searched
# as text, so they are listed for a manual look instead.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [ "${1:-}" = "--all" ]; then
  files=$(git ls-files --cached --others --exclude-standard)
else
  files=$(git diff --cached --name-only --diff-filter=ACM)
fi
[ -z "$files" ] && exit 0

patterns=$(mktemp)
trap 'rm -f "$patterns"' EXIT
[ -f .sensitive-map ] && cut -f1 .sensitive-map | grep -v '^$' > "$patterns"

generic='-----BEGIN [A-Z ]*PRIVATE KEY-----|\b2[0-9a-fA-F]{3}:[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}:|\b([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b|\b192\.168\.[0-9]{1,3}\.[0-9]{1,3}\b|\b10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b|\bgh[pousr]_[A-Za-z0-9]{20,}|\bsk-[A-Za-z0-9_-]{20,}'

failed=0
images=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in
    .sensitive-map|scripts/check-sensitive.sh|scripts/sanitize.py) continue ;;
    *.png|*.jpg|*.jpeg|*.gif|*.webp) images+=("$f"); continue ;;
  esac
  # grep exits 0 on a match, 1 on no match and 2 on an error. Treat errors as
  # failures so a broken check can never pass silently.
  if [ -s "$patterns" ]; then
    rc=0; grep -qF -f "$patterns" -- "$f" || rc=$?
    if [ "$rc" -ne 1 ]; then
      echo "BLOCKED: $f contains a value from .sensitive-map (line numbers below, values hidden)"
      grep -nF -f "$patterns" -- "$f" | cut -d: -f1 | sed 's/^/  line /' || true
      failed=1
    fi
  fi
  rc=0; grep -qE -e "$generic" -- "$f" || rc=$?
  if [ "$rc" -ne 1 ]; then
    echo "BLOCKED: $f matches a generic sensitive pattern (IP, MAC, key or token)"
    grep -nE -e "$generic" -- "$f" | cut -d: -f1 | sed 's/^/  line /' || true
    failed=1
  fi
done <<< "$files"

if [ ${#images[@]} -gt 0 ]; then
  echo "Images in this commit (check each one by eye before pushing):"
  printf '  %s\n' "${images[@]}"
fi

if [ "$failed" -ne 0 ]; then
  echo
  echo "Fix with: python3 scripts/sanitize.py <file>"
  exit 1
fi
echo "Sensitive check passed."
