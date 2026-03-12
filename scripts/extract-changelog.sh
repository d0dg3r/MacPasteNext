#!/bin/bash
set -euo pipefail

TAG="${1:-}"
CHANGELOG_FILE="${2:-CHANGELOG.md}"
OUTPUT_FILE="${3:-release-notes.md}"
MODE="${4:-allow-missing}"

if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag> [changelog_file] [output_file] [allow-missing|require-entry]"
  exit 1
fi

if [ ! -f "$CHANGELOG_FILE" ]; then
  echo "Changelog not found: $CHANGELOG_FILE"
  exit 1
fi

python3 - "$TAG" "$CHANGELOG_FILE" "$OUTPUT_FILE" "$MODE" <<'PY'
import re
import sys
from pathlib import Path

tag = sys.argv[1]
changelog_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])
mode = sys.argv[4]

text = changelog_path.read_text(encoding="utf-8")
lines = text.splitlines()

header_re = re.compile(r"^## \[" + re.escape(tag) + r"\](?:\s*-\s*(.*))?$")
next_header_re = re.compile(r"^## \[")

start_idx = None
date_part = ""
for i, line in enumerate(lines):
    m = header_re.match(line.strip())
    if m:
        start_idx = i
        date_part = (m.group(1) or "").strip()
        break

if start_idx is None:
    if mode == "require-entry":
        print(f"ERROR: No changelog entry found for tag {tag}", file=sys.stderr)
        sys.exit(2)
    output_path.write_text(
        f"## {tag}\n\nNo changelog entry found for this tag.\n",
        encoding="utf-8",
    )
    sys.exit(0)

body_lines = []
for j in range(start_idx + 1, len(lines)):
    if next_header_re.match(lines[j].strip()):
        break
    body_lines.append(lines[j])

while body_lines and not body_lines[0].strip():
    body_lines.pop(0)
while body_lines and not body_lines[-1].strip():
    body_lines.pop()

title = f"## {tag}"
if date_part:
    title = f"## {tag} - {date_part}"

body = "\n".join(body_lines).strip()
if not body:
    body = "No additional notes provided."

output_path.write_text(f"{title}\n\n{body}\n", encoding="utf-8")
PY

echo "Generated release notes: $OUTPUT_FILE"
