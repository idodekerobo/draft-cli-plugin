---
name: draft-setup
description: >
  PM brain initialization. Runs a short conversational interview to derive
  product context, then writes structured files to the workspace so every
  future session starts grounded. Run once at onboarding, or anytime to
  refresh context after a significant shift.
---

# /draft:setup — PM Brain Initialization

You are loading the PM brain with context about what the user is building, who they're building it for, and how they work. This interview takes about 3–5 minutes.

The goal is **derived context, not transcribed answers** — synthesize what the user says into structured knowledge, don't just copy their words.

---

## Before starting

### Profile detection (first-time users only)

Check whether a profile is already configured:

```bash
python3 -c "
from pathlib import Path
active_file = Path.home() / '.draft' / 'active-profile'
if active_file.exists() and active_file.read_text().strip():
    print('has_profile')
else:
    print('no_profile')
"
```

- **If `has_profile`**: skip this section and go directly to the context check below.
- **If `no_profile`** (first-time user): ask for a profile name before the interview:

  Use the **AskUserQuestion** tool to ask:
  > "What should we call this workspace? (Default: `<cwd-slug>` — based on your current directory)"

  Derive the CWD slug first, then ask:
  ```bash
  python3 -c "
  import os, re
  cwd = os.path.basename(os.getcwd())
  slug = cwd.lower()
  slug = re.sub(r'[\s_]+', '-', slug)
  slug = re.sub(r'[^a-z0-9-]', '', slug)
  slug = slug[:40].strip('-') or 'default'
  print(slug)
  "
  ```

  Wait for the user's response. If they accept the default, use the CWD slug. Otherwise use their typed name (apply the same slug transformation).

  Then create the profile directory and set active-profile:
  ```bash
  python3 - <<'PYEOF'
  import re
  from pathlib import Path

  name = "<chosen-slug>"
  base = Path.home() / ".draft" / "workspaces" / name
  personal = Path.home() / ".draft" / "personal"

  # Create workspace directories (no personal/ — that's global)
  for subdir in [
      base / "context" / "company" / "log",
      base / "context" / "product" / "log",
      base / "context" / "team" / "log",
      base / "context" / "priorities" / "log",
      base / "context" / "decisions",
      base / "docs",
      base / "config",
  ]:
      subdir.mkdir(parents=True, exist_ok=True)

  for dim in ["company", "product", "team", "priorities"]:
      idx = base / "context" / dim / "index.md"
      idx.write_text(f"---\nname: {dim}\ndescription: >\n  No information recorded yet.\nlast_updated: \"\"\nsource: \"\"\n---\n")

  (base / "context" / "tensions.md").write_text(
      "# Tensions\n\nActive contradictions and inconsistencies noticed across context dimensions.\n"
  )
  (base / "docs" / ".gitkeep").touch()

  # Create global personal layer if it doesn't exist yet
  if not personal.exists():
      (personal / "user").mkdir(parents=True, exist_ok=True)
      (personal / "wip").mkdir(parents=True, exist_ok=True)
      (personal / "user" / "index.md").write_text(
          "---\nname: user\ndescription: >\n  No information recorded yet.\nlast_updated: \"\"\nsource: \"\"\n---\n"
      )
      (personal / "memory.md").write_text(
          "---\nname: memory\ndescription: Vocabulary, working preferences, and non-obvious patterns.\nlast_updated: \"\"\nsource: \"\"\n---\n\n## Vocabulary\n\n## Preferences\n\n## Goals\n\n## Patterns\n"
      )

  # Write active-profile
  (Path.home() / ".draft" / "active-profile").write_text(name + "\n")

  print(f"Profile '{name}' created.")
  PYEOF
  ```

  Update `DRAFT_WORKSPACE` for this session:
  ```bash
  export DRAFT_WORKSPACE="$HOME/.draft/workspaces/<chosen-slug>"
  ```

---

### Context check

Check whether context already exists in the current workspace:

```bash
python3 -c "
import os
from pathlib import Path
ws = os.environ.get('DRAFT_WORKSPACE', os.path.expanduser('~/.draft/workspaces/default'))
files = list(Path(ws, 'context').glob('*/index.md'))
has_content = any(
    '---' in Path(f).read_text() and 'No information recorded yet' not in Path(f).read_text()
    for f in files
)
print('has_content' if has_content else 'empty')
" 2>/dev/null || echo "empty"
```

- **If `empty`**: deliver the Welcome orientation below, then run the full interview from Q1
- **If `has_content`**: run the re-run flow instead (see end of this file)

---

## Welcome (first-time only)

Before asking Q1, deliver this orientation. Keep it warm but brief — don't pad it.

> "Welcome to Draft — your AI-powered PM co-pilot.
>
> A few things to know before we start:
>
> **Your workspace** lives at `~/.draft/workspaces/<profile-name>/`. Everything Draft learns about your product, team, and priorities is stored there as plain markdown files — you can read, edit, or version-control them like any other file. You can have multiple named workspaces for different projects or clients — run `/draft:profiles` to manage them.
>
> **How updates happen:** Draft writes to your workspace after this setup interview, and keeps it fresh as you work. Whenever you share a decision, a shift in priorities, or a team change, Draft will update the relevant files automatically. You can also say `update [company / product / team / priorities]` at any point to trigger an explicit refresh.
>
> **Change history:** Each context dimension has a `log/` subdirectory. Draft writes a timestamped entry whenever something meaningful changes — so you always have a record of how your thinking evolved.
>
> Here's the layout:
>
> ```
> ~/.draft/
> ├── workspaces/
> │   └── <profile-name>/       ← your active workspace
> │       ├── context/
> │       │   ├── company/      ← what you're building, business model, stage
> │       │   ├── product/      ← product state, target user, key bets, roadmap
> │       │   ├── priorities/   ← active sprint, top priorities, blockers
> │       │   ├── team/         ← structure, who does what, capacity
> │       │   └── decisions/    ← key decisions with status (active/superseded/parked)
> │       ├── config/           ← collaboration config (created when you set up team sharing)
> │       └── docs/             ← written artifacts (analyses, PRDs, strategies)
> └── personal/                 ← your global layer (shared across all profiles, never shared with team)
>     ├── user/                 ← your role and working style
>     ├── memory.md             ← vocabulary, preferences, recurring patterns
>     └── wip/                  ← drafts not ready to share
> ```
>
> **How Draft works:** Draft uses three specialized agents:
>
> - **@draft-researcher** — finds and retrieves information (workspace files, integrations, web)
> - **@draft-executor** — takes concrete actions (writes PRDs, creates Linear issues, sends Slack messages)
> - **@draft-learner** — updates persistent memory (keeps your workspace files accurate over time)
>
> Most requests follow the same pattern: researcher gathers context → executor acts → learner saves what changed.
>
> Let's load your PM brain. This takes about 3–5 minutes."

Then proceed directly to Q1 — no gap, no extra preamble.

---

## The interview

Ask questions **one at a time**. Wait for the full answer before asking the next. Adapt each question to what you've already heard — skip or merge questions if the user already answered them.

If the user says **"skip"** at any point, stop the interview immediately and say: "No problem — run `/draft:setup` anytime you're ready to load your PM brain."

---

### Q1 — What you're building

Ask:
> "What are you building, and who's it for? Give me the one-liner."

Listen for: product name, problem being solved, target customer, stage (pre-launch / early users / scaling / growth).

If the answer is vague on the customer, probe once:
> "Who specifically — a job title, a type of company, a situation they're in?"

---

### Q2 — Distribution and traction

Ask, adapted to stage:
- **Pre-launch:** "Who are you building with right now — any design partners or early testers?"
- **Post-launch:** "How do users find you today, and how many do you have?"

Listen for: acquisition channel, number of users or customers, whether they're paying, how the user thinks about growth right now.

Skip this question if they already answered it in Q1.

---

### Q3 — Team

Ask:
> "What does your team look like?"

Listen for: team size, who does what (eng, design, PM, founders), whether they're solo. One follow-up max if the answer is thin. Keep this short.

---

### Q4 — Current focus

Ask:
> "What's the most important thing you're working on right now?"

Listen for: specific milestone or sprint goal, the bet they're making, blockers, what success looks like this week or month.

If vague, probe once:
> "What would make this week a win?"

---

### Q5 — How you work

Ask:
> "What tools do you use day-to-day, and what does a typical week look like?"

Listen for: project management (Linear, Jira, Notion), communication (Slack, email), planning cadence, how decisions get made.

---

### Q5.5 — Team collaboration

Use the **AskUserQuestion** tool to ask:
> "Do you want to use Draft together with your team? This lets you share your context layer and keep it fresh across multiple people."

If **yes**: Say "Let's set that up." → invoke `/draft:setup-collab` inline (call it as a skill before proceeding to Q6).

If **no**: Continue to Q6 normally. No config files created.

---

### Q6 — Hardest problem

Ask:
> "What's the hardest PM problem you're dealing with right now?"

This is the most important question. Let them answer fully — don't rush or redirect. Listen for the actual underlying tension.

---

## After the interview

Once all answers are in (or the user says they're done), do the following in order:

### 1. Synthesize

Do not pass raw answers to @draft-learner. Before writing, derive:

- **company:** name, what they do, business model (B2B/B2C/marketplace/etc.), stage, funding if mentioned
- **product:** product name, problem it solves, target user (specific, not vague), how users find it today, key bets or hypotheses
- **user:** their role, team context, working style, communication preferences, tools they use
- **team:** size, structure, who does what, capacity constraints if mentioned
- **priorities:** current milestone or sprint goal, the single most important thing, open questions or blockers
- **memory/vocabulary:** domain-specific terms they used, working preferences, goals they named

### 2. Call @draft-learner

Pass the synthesized content as a single, structured message. Instruct @draft-learner to write:

**Context files** (under `$DRAFT_WORKSPACE/context/`):
- `$DRAFT_WORKSPACE/context/company/index.md`
- `$DRAFT_WORKSPACE/context/product/index.md`
- `$DRAFT_WORKSPACE/context/team/index.md`
- `$DRAFT_WORKSPACE/context/priorities/index.md`

**Personal files** (under `~/.draft/personal/` — global layer, NOT inside `$DRAFT_WORKSPACE`):
- `~/.draft/personal/user/index.md`
- `~/.draft/personal/memory.md`

Each index file must have complete frontmatter:
- `name`: dimension name
- `description`: 2–10 sentences, specific and factual
- `last_updated`: today's date (YYYY-MM-DD)
- `source: /setup interview`

For `priorities/index.md`, also include the full body content.

Do NOT write log entries during /setup — this is the initial state.

### 3. Confirm

After @draft-learner writes the files, confirm to the user:

- Which files were written (paths)
- One-line summary of what's in each
- Invite corrections: "Does that capture it right? Say 'update [company/product/team/priorities/user]' to fix anything."

### 4. Ask the first real question

End with one sharp, specific question grounded in what you just learned. Base it on the hardest problem they named in Q6, or the most interesting tension you noticed.

---

## Re-run flow

If context files already have content, start with:

> "Your PM brain already has context. Here's what I have:
> [show one-line description per dimension — read from frontmatter]
>
> Want to do a full refresh, or just tell me what's changed?"

- **Full refresh**: run the interview from Q1, overwrite all context files
- **What's changed**: ask "Walk me through what's different since we last synced." Then call @draft-learner to update only the relevant dimensions and write log entries for any changes to `product/` or `priorities/`.

---

## Rules

- One question at a time — never ask two questions in the same message
- No preamble before questions ("Great answer!" / "Thanks for sharing" = never)
- Adapt — skip questions already answered, merge where natural
- Synthesize before writing — derived context beats transcribed answers
- The description field in frontmatter is loaded every session — write it like a briefing note, not a data dump
