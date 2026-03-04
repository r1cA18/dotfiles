---
name: name
description: "Rename the current session's status line label"
argument-hint: "[new-name]"
---

Rename the status line session label. Determine the tmpdir and find the state file:

```bash
TMPDIR=$(node -e "process.stdout.write(require('os').tmpdir())")
STATE_FILE=$(ls -t "${TMPDIR}"/cc-nametag-*.json 2>/dev/null | head -1)
if [ -n "$STATE_FILE" ]; then
  SESSION_ID=$(basename "$STATE_FILE" | sed 's/^cc-nametag-//;s/\.json$//')
  bun x cc-nametag set-name "$ARGUMENTS" --session "$SESSION_ID"
else
  echo "No active session state file found"
fi
```
