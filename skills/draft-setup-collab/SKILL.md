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

## Step 0: Resolve workspace path

Before writing any files, resolve the active workspace path at runtime — do not
rely on the `$DRAFT_WORKSPACE` env var, which may not reflect the current profile yet.

```bash
python3 -c "
from pathlib import Path
profile_file = Path.home() / '.draft' / 'active-profile'
profile = profile_file.read_text().strip() if profile_file.exists() else 'default'
ws = Path.home() / '.draft' / 'workspaces' / profile
print(str(ws))
"
```

Store the result as `ACTIVE_WORKSPACE`. Use it everywhere a workspace path is needed in this skill.

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

Use the **AskUserQuestion** tool to ask:
> "gh CLI isn't installed. Install it now? (macOS: `brew install gh` / Linux: `sudo apt install gh`)"

- If **yes**: run the appropriate install command, then re-run `gh auth status`.
  - If still not installed: hard stop — "Install gh CLI and re-run `/draft:setup-collab`."
- If **no**: hard stop — "gh CLI is required. Install it and re-run `/draft:setup-collab`."

**If installed but not authenticated:**

Use the **AskUserQuestion** tool to ask:
> "You're not logged into GitHub. Authenticate now with `gh auth login --web`?"

- If **yes**: run `gh auth login --web`. This opens the user's browser — terminal waits for OAuth callback.
  - If `--web` fails (SSH/headless/no browser): hard stop — "Run `gh auth login` in your terminal, then re-run `/draft:setup-collab`."
  - After auth: verify with `gh auth status`. If still not authenticated: hard stop.
- If **no**: hard stop — "GitHub auth is required. Run `gh auth login` and re-run `/draft:setup-collab`."

**If installed and authenticated:** proceed to Step 2.

---

## Step 2: Clarify intent

Use the **AskUserQuestion** tool to ask:
> "Are you the first person on your team setting up Draft — or are you connecting to a shared repo your teammate already configured?"

- **"First person / setting it up"** → curator path → go to **Step 2a (choose repo)**
- **"Connecting to existing"** → teammate path → go to **Step 2b (enter URL)**

---

## Step 2a: Choose / create repo (curator path)

Get the authenticated username:

```bash
gh api user --jq .login
```

Use the **AskUserQuestion** tool to ask:
> "Create a new private GitHub repo, or use one you already have?
> A) Create new repo (default name: `draft-context`)
> B) Use existing repo — I'll paste the URL"

**Option A — New dedicated repo:**

Use the **AskUserQuestion** tool to ask:
> "What should the repo be called? (Press Enter for `draft-context`)"

- If the user presses Enter or leaves blank: use `draft-context`.
- Otherwise: use their input, slugified (lowercase, hyphens only, no spaces).

Create the repo:
```bash
gh repo create [username]/[repo-name] --private --description "Draft team context"
```

Set: `team_repo_url = github.com/[username]/[repo-name]`, `team_repo_subdir = root`

**Option B — Existing repo:**

Use the **AskUserQuestion** tool to ask:
> "Paste the GitHub repo URL (e.g. `github.com/your-org/your-repo`):"

Then use the **AskUserQuestion** tool to ask:
> "Which folder inside that repo should Draft write to? (Press Enter for `.draft`, or type a path like `context` or `/` for root)"

- Enter pressed → `team_repo_subdir = .draft`
- `/` entered → `team_repo_subdir = root`
- Custom path typed → `team_repo_subdir = [user input]`

**For either option — verify the repo:**

```bash
gh repo view [team_repo_url] --json name,isPrivate,isEmpty
```

- If repo not found: "Can't find that repo. Check the URL and try again." Loop back to top of Step 2a.
- If public: use the **AskUserQuestion** tool to ask:
  > "That repo is public — your product context will be visible to anyone. Continue anyway?"
  - If no (default): loop back to Step 2a.
  - If yes: proceed.

Proceed to **Step 3**.

---

## Step 2b: Connect to existing repo (teammate path)

Use the **AskUserQuestion** tool to ask:
> "Paste the GitHub repo URL your teammate shared with you:"

Then use the **AskUserQuestion** tool to ask:
> "Which folder inside that repo does Draft use? (Press Enter for `.draft`, or type the path your teammate set — usually `root` or `.draft`)"

- Enter pressed → `team_repo_subdir = .draft`
- `/` or `root` entered → `team_repo_subdir = root`
- Custom path typed → `team_repo_subdir = [user input]`

Verify the repo:
```bash
gh repo view [team_repo_url] --json name,isPrivate
```

If not found: "Can't reach that repo. Check the URL and your access, then try again." Hard stop.

Proceed to **Step 3**.

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
