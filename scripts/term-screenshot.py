#!/usr/bin/env python3
"""Turn real terminal output into a clean PNG for the docs.

The text is sanitized first (scripts/sanitize.py), then drawn in a terminal
style window and captured with headless Google Chrome.

Usage:
  python3 scripts/term-screenshot.py <input.txt> <output.png> "Window title"

Lines in the input that start with "$ " are drawn as commands.
"""
import html
import pathlib
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from sanitize import load_map, sanitize  # noqa: E402

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WIDTH = 980
LINE_HEIGHT = 20

PAGE = """<!doctype html><meta charset="utf-8"><style>
body{{margin:0;background:#e9edf2;font:14px/{lh}px Menlo,Monaco,monospace}}
.win{{margin:20px;border-radius:10px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,.25);background:#1e2430}}
.bar{{background:#2b3240;color:#aab3c2;font:12px -apple-system,Helvetica,sans-serif;padding:8px 12px;position:relative;text-align:center}}
.dots{{position:absolute;left:12px;top:9px}}.dots i{{display:inline-block;width:11px;height:11px;border-radius:50%;margin-right:6px}}
pre{{margin:0;padding:14px 16px;color:#d6dde8;white-space:pre-wrap;word-break:break-all}}
.cmd{{color:#8fd18f}}.ph{{color:#f2c46d}}
</style><div class="win"><div class="bar"><span class="dots"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i></span>{title}</div><pre>{body}</pre></div>"""


def render_line(line):
    escaped = html.escape(line)
    # Highlight placeholders like <server-ip> so readers see what was redacted.
    escaped = re.sub(r"&lt;([a-z0-9-]+)&gt;", r'<span class="ph">&lt;\1&gt;</span>', escaped)
    if line.startswith("$ "):
        return f'<span class="cmd">{escaped}</span>'
    return escaped


def main():
    src, out, title = sys.argv[1], sys.argv[2], sys.argv[3]
    text = sanitize(pathlib.Path(src).read_text(encoding="utf-8"), load_map()).rstrip("\n")
    lines = text.split("\n")
    body = "\n".join(render_line(l) for l in lines)
    height = 40 + 34 + 28 + LINE_HEIGHT * sum(max(1, len(l) // 110 + 1) for l in lines)
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
        f.write(PAGE.format(lh=LINE_HEIGHT, title=html.escape(title), body=body))
        page = f.name
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
         "--force-device-scale-factor=2", f"--window-size={WIDTH},{height}",
         f"--screenshot={pathlib.Path(out).resolve()}", f"file://{page}"],
        check=True, capture_output=True,
    )
    pathlib.Path(page).unlink()
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
