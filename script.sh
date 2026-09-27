#!/usr/bin/env bash
# add-ahrefs.sh - insert Ahrefs analytics tag into every HTML <head>, then push
set -euo pipefail

TAG='<script src="https://analytics.ahrefs.com/analytics.js" data-key="g4GhbVEwHjJpe1617i8Uag" async></script>'

git rev-parse --is-inside-work-tree >/dev/null

TAG="$TAG" python3 - <<'EOF'
import os, re, subprocess
tag = os.environ["TAG"]
files = subprocess.run(["git", "ls-files", "*.html", "*.htm"],
                       capture_output=True, text=True, check=True).stdout.split()
changed = 0
for f in files:
    with open(f, encoding="utf-8", errors="surrogateescape") as fh:
        s = fh.read()
    if "analytics.ahrefs.com/analytics.js" in s:
        continue
    new, n = re.subn(r"(?i)</head>", "  " + tag + "\n</head>", s, count=1)
    if n:
        with open(f, "w", encoding="utf-8", errors="surrogateescape") as fh:
            fh.write(new)
        print("updated:", f)
        changed += 1
print(changed, "file(s) updated")
EOF

if ! git diff --quiet; then
    git add -A
    git commit -m "Add Ahrefs analytics tag"
    git push
else
    echo "Nothing to commit."
fi
