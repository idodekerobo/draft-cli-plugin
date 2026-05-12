---
name: draft-setup-collab
description: >
  Collaboration configuration for Draft. Sets up gh CLI auth, configures the
  shared GitHub repo, writes config files, and seeds the shared repo on first
  use. Invoked from /draft:setup Q5.5 or run standalone at any time.
---

# /draft:setup-collab — Collaboration Configuration

Configure Draft to share your context layer with teammates via a shared GitHub repo.
Can be run standalone (`/draft:setup-collab`) or invoked inline from `/draft:setup`.

---

## Step 1: Check gh CLI

Run:
```bash
gh auth status
```

**If gh is not installed:**

Detect OS:
```bash
uname -s
```

- macOS → "Run: `brew install gh`"
- Linux → "Run: `sudo apt install gh`  (or see https://cli.github.com)"

Present the install command. Ask: "Run it now? [Y/n]"

If yes: execute the install command. Then run `gh auth status` again. If still not installed: hard stop — "Install gh CLI and re-run `/draft:setup-collab`."

**If installed but not authenticated:**

Run:
```bash
gh auth login --web
```

This opens the user's browser. Terminal waits for OAuth callback.

If `--web` fails (SSH/headless/no browser): hard stop — "Run `gh auth login` in your terminal, then re-run `/draft:setup-collab`."

After auth: verify with `gh auth status`. If still not authenticated: hard stop.

**If installed and authenticated:** proceed to Step 2.

---

## Step 2: Choose shared repo

Ask:
> "Where should Draft store your shared context?
>
> A) Create a new private repo (github.com/[your-username]/draft-context)
> B) Use an existing repo — paste the URL
>
> [A/B]"

**Option A — New dedicated repo:**

Get the authenticated username:
```bash
gh api user --jq .login
```

Create the repo:
```bash
gh repo create [username]/draft-context --private --description "Draft team context"
```

Set: `team_repo_url = github.com/[username]/draft-context`, `team_repo_subdir = root`

**Option B — Existing repo:**

Ask for the URL. Then ask:
> "Which folder inside the repo should Draft write to?
> (press Enter for `.draft`, type a path like `context` or `team-wiki`, or `/` for repo root)"

- Enter pressed → `team_repo_subdir = .draft`
- `/` entered → `team_repo_subdir = root`
- Custom path typed → `team_repo_subdir = [user input]`

**For either option — verify the repo:**

```bash
gh repo view [team_repo_url] --json name,isPrivate
```

- If public: warn "This repo is public — your product context will be visible to anyone. Are you sure? [y/N]" (default: abort). If they confirm yes: proceed.
- If not found: "Can't find that repo. Check the URL and try again." Loop back.

---

## Step 3: Write config files

Write `$DRAFT_WORKSPACE/config/collaboration.md`:

```yaml
---
mode: github
team_repo_url: [from step 2]
team_repo_subdir: [from step 2]
repo_is_private: [true/false from gh repo view]
teammates:
  - [gh username from `gh api user --jq .login`]
---
```

Write `$DRAFT_WORKSPACE/config/local.md`:

```yaml
---
gh_cli_authenticated: true
last_published: null
last_loaded: null
---
```

Create the config directory if it doesn't exist:
```bash
mkdir -p "$DRAFT_WORKSPACE/config"
```

---

## Step 4: Check if shared repo is seeded

Shallow clone to a temp directory:
```bash
TMPDIR=$(mktemp -d /tmp/draft-check-XXXX)
git clone --depth 1 [team_repo_url] "$TMPDIR"
```

**Check signal:** Look for `[subdir]/config/collaboration.md` in the cloned repo.
- Use `root` to mean the repo root (no subdir prefix).
- Example: if `team_repo_subdir = .draft`, check for `.draft/config/collaboration.md`.

```bash
# Example check (adjust path based on team_repo_subdir):
ls "$TMPDIR/[subdir_path]/config/collaboration.md" 2>/dev/null
```

Then:
```bash
rm -rf "$TMPDIR"
```

**If `config/collaboration.md` does NOT exist in the cloned repo:**
- Draft has not been configured at this location. This user is the curator. → Go to Step 5 (auto-seed).

**If `config/collaboration.md` exists:**
- Existing Draft setup found. This user is a teammate connecting to an existing repo. → Skip to Step 6.

**NOTE:** Check `config/collaboration.md` — NOT `CHANGES.jsonl`. `config/collaboration.md` is the authoritative signal that Draft has been set up here. `CHANGES.jsonl` may legitimately be absent between setup and first `/publish-team`.

---

## Step 5: Auto-seed (curator path only)

Run the `/draft:publish-team` flow with `--no-confirm` flag. This seeds the shared repo with the current workspace context.

Show: "Seeding shared repo with your current context..."

After publish completes successfully: `last_published` is updated in `config/local.md` by the publish flow.

If publish fails: "Initial publish failed. Run `/publish-team` when you're ready to share your context."

---

## Step 6: Confirm and next steps

**If auto-seeded (curator path):**

Get the gh username and org from the team_repo_url to construct the settings URL.

Print:
```
Done. Your context is live.

Share this with your teammates: [team_repo_url]
Add them as collaborators: https://github.com/[org]/[repo]/settings/access

They'll configure Draft to use this repo when they run /draft:setup.
```

**If connected to existing (teammate path):**

Print:
```
Done. You're connected to [team_repo_url].

Run /load-team to pull your team's latest context into this session.
```
