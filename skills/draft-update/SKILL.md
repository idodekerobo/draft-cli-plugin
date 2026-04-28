# /draft:update

Check for and apply Draft plugin updates.

## When to invoke
- User runs `/draft:update`
- User asks to update Draft, check for updates, or upgrade the plugin

## What to do

### Step 1 — Check current state

Run these two commands:
```
cat ~/.draft/version
cat ~/.draft/last-update-check
```

If `last-update-check` is missing or stale, force a fresh check:
```
bash ~/.draft/scripts/draft-update-check.sh --force
cat ~/.draft/last-update-check
```

### Step 2 — Report to user

- If `UP_TO_DATE`: tell the user they're already on the latest version. Done.
- If `UPGRADE_AVAILABLE <old> <new>`: tell the user v`<new>` is available (they're on v`<old>`) and ask if they'd like to proceed with the update.

### Step 3 — On confirmation, run the update

```
bash ~/.draft/scripts/draft-update.sh
```

### Step 4 — Summarize what changed

Fetch the CHANGELOG and show the user what's new in the version they just installed:
```
curl -fsSL https://raw.githubusercontent.com/idodekerobo/draft-cli-plugin/main/CHANGELOG.md
```

Find the entries between their old and new version and give a brief plain-English summary.

### Step 5 — Remind the user to restart

Tell them to restart their session (close and reopen Claude Code / Codex / Cursor) for all changes to take effect.

---

## Notes
- Always ask for confirmation before running the update — never run it automatically
- The update script is workspace-safe: it never touches `~/.draft/workspace/` (your PM brain data)
- Claude Code plugin agent/skill files are managed by Anthropic's plugin system and update separately from this script
