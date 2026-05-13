---
name: draft-switch
description: >
  Activate a named Draft profile. Writes the profile name to ~/.draft/active-profile.
  Takes effect on the next session restart. With no args, shows the currently active profile.
---

# /draft:switch — Profile Activation

## Overview

`/draft:switch <name>` activates a named Draft profile. The change takes effect the next
time a session starts — the current session's `$DRAFT_WORKSPACE` does not change mid-session.
This is correct behavior: context is resolved once at session start, not dynamically.

`/draft:switch` with no arguments shows the currently active profile.

---

## Execution

### Step 1 — Determine mode

Check whether the user provided a profile name as an argument:

- **With a name argument** (`/draft:switch <name>`): activate that profile → go to Step 2
- **With no argument** (`/draft:switch`): show current profile → go to Step 4

---

### Step 2 — Validate the profile exists

```bash
python3 -c "
from pathlib import Path
import sys
name = '<profile-name>'
target = Path.home() / '.draft' / 'workspaces' / name
if not target.exists():
    print('NOT_FOUND')
else:
    print('FOUND')
"
```

- **If `NOT_FOUND`**: respond with:
  > `Profile '<name>' not found. Run /draft:profiles to see available profiles.`

  Stop here — do not write to active-profile.

- **If `FOUND`**: continue to Step 3.

---

### Step 3 — Write active-profile and confirm

```bash
echo "<profile-name>" > ~/.draft/active-profile
```

If the write fails (non-zero exit), emit an error:
> `[Draft] Failed to write active-profile. Check file permissions for ~/.draft/`

On success, confirm to the user:
> `[Draft] Switched to profile: <name>. Takes effect next session — restart your session to load this context.`

---

### Step 4 — No-arg: show current profile

```bash
python3 -c "
from pathlib import Path
active = Path.home() / '.draft' / 'active-profile'
if active.exists():
    name = active.read_text().strip()
    print(f'Active profile: {name}. Run /draft:profiles to see all profiles.')
else:
    print('No active profile set. Run /draft:profiles to create one.')
"
```

Output the result directly — do not add commentary.

---

## Error handling

| Scenario | Response |
|----------|----------|
| Profile name doesn't exist | `Profile '<name>' not found. Run /draft:profiles to see available profiles.` |
| `~/.draft/active-profile` write fails | `[Draft] Failed to write active-profile. Check file permissions for ~/.draft/` |
| No argument, no active-profile file | `No active profile set. Run /draft:profiles to create one.` |

---

## Notes

- `/draft:switch` only activates an existing profile — it does not create one. Use `/draft:profiles create <name>` to create a new profile.
- The change takes effect at the start of the **next session**. The current session's `$DRAFT_WORKSPACE` does not change mid-session.
- To list all available profiles: run `/draft:profiles`
- To create a new profile: run `/draft:profiles create <name>`
