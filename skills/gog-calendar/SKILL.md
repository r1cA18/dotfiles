---
name: gog-calendar
description: Google Calendar operations via gogcli. List events, create/update/delete events, check free/busy, search. Triggers on calendar-related requests.
---

# Google Calendar (gogcli)

## Prerequisites

- `gog` command available on PATH (installed via Nix)
- Google OAuth configured: `gog auth credentials` + `gog auth add`
- Environment: `GOG_JSON=1`, `GOG_TIMEZONE=Asia/Tokyo`

## Quick Reference

### List events

```bash
# Today's events
GOG_JSON=1 gog calendar events primary --from today --to tomorrow

# This week
GOG_JSON=1 gog calendar events primary --from today --days 7

# Specific date range
GOG_JSON=1 gog calendar events primary --from 2026-02-15 --to 2026-02-20

# All calendars
GOG_JSON=1 gog calendar events --all --from today --to tomorrow

# Search events
GOG_JSON=1 gog calendar search "meeting" --from today --days 30
```

### Create events

```bash
# Timed event
GOG_JSON=1 gog calendar create primary \
  --summary "Team standup" \
  --from "2026-02-16T10:00:00+09:00" \
  --to "2026-02-16T10:30:00+09:00"

# With location and description
GOG_JSON=1 gog calendar create primary \
  --summary "Lunch with team" \
  --from "2026-02-16T12:00:00+09:00" \
  --to "2026-02-16T13:00:00+09:00" \
  --location "Shibuya office" \
  --description "Monthly team lunch"

# All-day event
GOG_JSON=1 gog calendar create primary \
  --summary "Holiday" \
  --from 2026-03-01 --to 2026-03-02 \
  --all-day

# With Google Meet
GOG_JSON=1 gog calendar create primary \
  --summary "Remote sync" \
  --from "2026-02-16T14:00:00+09:00" \
  --to "2026-02-16T14:30:00+09:00" \
  --with-meet
```

### Update events

```bash
GOG_JSON=1 gog calendar update primary EVENT_ID \
  --summary "Updated title" \
  --from "2026-02-16T11:00:00+09:00"
```

### Delete events

```bash
gog calendar delete primary EVENT_ID --force
```

### Other useful commands

```bash
# List all calendars
GOG_JSON=1 gog calendar calendars

# Check free/busy
GOG_JSON=1 gog calendar freebusy primary --from today --to tomorrow

# Find conflicts
GOG_JSON=1 gog calendar conflicts --from today --days 7

# Focus time
GOG_JSON=1 gog calendar focus-time primary \
  --from "2026-02-16T09:00:00+09:00" \
  --to "2026-02-16T12:00:00+09:00"
```

## Notes

- Always use `GOG_JSON=1` for machine-readable output
- Calendar ID `primary` refers to the user's main calendar
- Times should be RFC3339 with timezone (e.g., `2026-02-16T14:00:00+09:00`)
- Relative dates work: `today`, `tomorrow`, `monday`
- Use `--dry-run` to preview changes without executing
- Delete/update operations: always confirm with the user before executing
- Use `--force` only after explicit user approval
