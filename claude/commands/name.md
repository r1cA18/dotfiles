---
name: name
description: "Rename the current session's status line label"
argument-hint: "[new-name]"
---

Rename the status line session label. Run this Bash command, replacing NEW_NAME with the user's argument:

```bash
STATE_FILE=$(ls -t /tmp/cc-status-*.json 2>/dev/null | head -1)
if [ -n "$STATE_FILE" ]; then
  printf '{"name":"%s","source":"manual"}\n' "$ARGUMENTS" > "$STATE_FILE"
  echo "Renamed to: $ARGUMENTS"
else
  echo "No active session state file found"
fi
```
