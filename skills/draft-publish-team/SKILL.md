---
name: draft-publish-team
description: >
  Publishes the curator's local context to the shared GitHub repo. Reads
  change log entries since last publish, builds CHANGES.jsonl, pushes to the
  team repo via the separate-clone pattern. Run whenever you want teammates
  to see updated context.
---

# /draft:publish-team — Publish Context to Shared Repo

Push your local product context to the shared team repo so teammates can load it.

**Flags:** `--no-confirm` — skip the preview step (used by `/draft:setup-collab` auto-seed and automation).

---

## Step 1: Read config and verify auth

Read `$DRAFT_WORKSPACE/config/collaboration.json` using `json.loads()`.
Read `$DRAFT_WORKSPACE/config/local.json` using `json.loads()`.

If `config/collaboration.json` is missing or `mode` is not `github`:
```
Error: Collaboration not configured. Run /draft:setup-collab first.
```
Hard stop.

Verify gh auth:
```bash
gh auth status
```

If fails:
```
GitHub auth expired. Run `gh auth login --web` then re-run /publish-team.
```
Hard stop.

---

## Step 2: Collect changes

Read all files in `$DRAFT_WORKSPACE/context/*/log/` with modification timestamps newer than `config/local.json:last_published`.

- If `last_published` is `null` (from `local.json`): this is the first manual publish — read ALL log entries.
- If no log/ directories exist or they are empty: no log-based entries.

**Case: `last_published` is null AND no log entries exist**

First publish with no history. Generate synthetic CHANGES entries — one per context dimension where `index.md` description is not "No information recorded yet":

For each qualifying dimension, compute the ID deterministically via bash:
```bash
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
gh_username=$(gh api user --jq .login)
dimension="[company|product|team|priorities|decisions|tensions]"
file="context/${dimension}/index.md"
id=$(echo -n "${ts}${gh_username}${dimension}${file}" | sha256sum | cut -c1-8)
```

Generate CHANGES entry:
```jsonl
{"id":"[computed]","ts":"[current ISO 8601]","author":"[gh_username]","dimension":"[dim]","summary":"Initial context snapshot","file":"context/[dim]/index.md","log_entry":null}
```

**Case: no entries found since `last_published`**

Print: "Nothing new to publish since [last_published]."
Exit 0.

**IMPORTANT:** Never compute IDs mentally. Always run the sha256 bash command above.

---

## Step 3: Preview (skip if --no-confirm)

Show:
```
Publishing to: [team_repo_url] / [team_repo_subdir]
Changes:
  [N] entries across [dimensions list]
  [list of summaries, truncated at 80 chars each]
Teammates: [list from collaboration.json]

Confirm? [Y/n]
```

If `n` or `N`: "Aborted. Nothing published." Exit 0.

---

## Step 4: Execute — separate-clone pattern

**The Draft workspace (`~/.draft/workspace`) is NEVER initialized as a git repo.**
All git operations run in a short-lived temp directory.

```bash
TMPDIR=$(mktemp -d /tmp/draft-publish-XXXX)
git clone [team_repo_url] "$TMPDIR"
```

Set the subdir prefix. If `team_repo_subdir` is `root`, use no prefix (write to repo root):
```bash
# team_repo_subdir = root → SUBDIR_PATH="$TMPDIR"
# team_repo_subdir = .draft → SUBDIR_PATH="$TMPDIR/.draft"
# team_repo_subdir = [custom] → SUBDIR_PATH="$TMPDIR/[custom]"
```

Create target directories:
```bash
mkdir -p "$SUBDIR_PATH/context"
mkdir -p "$SUBDIR_PATH/config"
```

Copy context from workspace:
```bash
cp -r "$DRAFT_WORKSPACE/context/" "$SUBDIR_PATH/context/"
```

`personal/` is structurally excluded — it lives outside `context/` and is never under the copy source path.

Copy collaboration config:
```bash
cp "$DRAFT_WORKSPACE/config/collaboration.json" "$SUBDIR_PATH/config/collaboration.json"
```

Build `CHANGES.jsonl`:

1. Read existing `$SUBDIR_PATH/CHANGES.jsonl` if it exists (preserves history).
2. For each new CHANGES entry, compute ID via bash:
   ```bash
   id=$(echo -n "${ts}${author}${dimension}${file}" | sha256sum | cut -c1-8)
   ```
3. Append new entries (one JSON object per line).
4. Write back to `$SUBDIR_PATH/CHANGES.jsonl`.

Generate semantic commit message:
```
"[N] context updates: [comma-joined dimension list]"
```

Stage and commit:
```bash
# Adjust git add paths based on team_repo_subdir (root vs subdir)
git -C "$TMPDIR" add "[subdir_relative]/context/" "[subdir_relative]/config/" "[subdir_relative]/CHANGES.jsonl"
git -C "$TMPDIR" commit -m "[semantic message]"
git -C "$TMPDIR" push
```

**If push fails:**
```bash
rm -rf "$TMPDIR"
```
Print the error. DO NOT update `config/local.json`.
```
Publish failed. Check your network and repo access, then try again. Nothing was changed locally.
```
Exit 1.

```bash
rm -rf "$TMPDIR"
```

---

## Step 5: Update local state (success only)

Update `$DRAFT_WORKSPACE/config/local.json`:
- Read the file with `json.loads()`, set `last_published` to the current ISO 8601 timestamp, write back with `json.dumps()`.

Print:
```
Published [N] changes to [team_repo_url]
```
