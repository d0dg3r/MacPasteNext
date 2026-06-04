#!/usr/bin/env python3
"""Minimal Markdown -> HTML converter for Sparkle appcast <description>.

Only supports the subset our changelog actually uses:
  - `## Heading`        -> <h2>...</h2>
  - `- list item`       -> <ul><li>...</li></ul>
  - inline `code` spans -> <code>...</code>
  - blank lines close any open list
  - everything else     -> <p>...</p>
"""
from __future__ import annotations

import html
import re
import sys


def convert(text: str) -> str:
    out: list[str] = []
    in_list = False
    backtick = chr(0x60)
    inline_code_re = re.compile(
        backtick + r"([^" + backtick + r"]+)" + backtick
    )
    for raw in text.splitlines():
        line = raw.rstrip()
        if line.startswith("## "):
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append("<h2>" + html.escape(line[3:].strip()) + "</h2>")
        elif line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            body = html.escape(line[2:].strip())
            body = inline_code_re.sub(lambda m: "<code>" + m.group(1) + "</code>", body)
            out.append("<li>" + body + "</li>")
        elif not line:
            if in_list:
                out.append("</ul>")
                in_list = False
        else:
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append("<p>" + html.escape(line) + "</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("usage: markdown-to-html.py <markdown_file>\n")
        return 2
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        text = fh.read()
    sys.stdout.write(convert(text))
    if not text.endswith("\n"):
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
