---
name: draft-learn
description: >
  Saves something you learned, decided, or want to remember to your Draft workspace.
  Supports free-form input, structured tags, or a short conversational flow when
  invoked with no arguments. Automatically routes the learning to the right context
  file and writes a log entry when appropriate.
---

# /draft:learn — Save a Learning

Persist something to the Draft workspace: a decision, a priority shift, a product direction change, a company update, a team change, or a preference.

---

## Step 1 — Get the input

Check how the skill was invoked:

- **With a structured tag** (e.g. `/draft:learn [decision] drop the bridge daemon`): Extract the tag and content. Skip directly to Step 3.
- **With free-form args** (e.g. `/draft:learn we decided to drop the bridge daemon`): Use the args as the learning input. Proceed to Step 2.
- **With no args**: Ask exactly one question — no preamble, no greeting:

  > "What did you learn or decide?"

  Wait for the full answer. Then proceed to Step 2.

---

## Step 2 — Classify the learning

Read the input and infer the type. Use the table below. If the type is genuinely ambiguous after careful reading, ask one clarifying question — and only one:

> "Is this a decision you made, a priority shift, a product direction change, or something else?"

Do not ask for clarification if you can make a reasonable inference.

### Classification rules

**Decision** — a choice was made between options; something was formally resolved
Signal words: "decided", "going with", "chose", "agreed to", "we're not doing", "confirmed"
→ Primary destination: `context/decisions/{slug}.md`
→ If it affects product direction: also update `context/product/index.md` + log
→ If it affects the current sprint: also update `context/priorities/index.md` + log

**Priority shift** — a sprint item completed, dropped, added, or blocked; focus changed
Signal words: "done", "shipped", "dropped", "deferred", "blocked on", "moving on from", "next up", "no longer a priority", "pausing"
→ Destination: `context/priorities/index.md` + log

**Product direction** — strategy changed, ICP shifted, a bet changed, roadmap updated
Signal words: "pivoting", "the bet is now", "ICP is", "we're targeting", "changed the roadmap", "new direction", "repositioning"
→ Destination: `context/product/index.md` + log

**Company info** — structural company changes only
Signal words: "raised", "new investor", "pivoting the company", "rebranding", "acquired", "partnership signed", "new co-founder"
→ Destination: `context/company/index.md` + log (structural changes only — skip log for minor updates)

**Team change** — someone joined, left, or changed roles
Signal words: "hired", "quit", "left", "joined", "now owns", "taking over", "contractor starting", "role change"
→ Destination: `context/team/index.md` + log (structural changes only)

**Preference / Vocabulary / Pattern** — working style, terminology, recurring habits
Signal words: "I prefer", "from now on", "we call it", "our word for", "I always", "don't do X", "the term we use"
→ Destination: `memory/memory.md` (no log)

### Multiple destinations

A single learning can map to more than one file. For example:
- "We decided to kill the bridge daemon and focus on the plugin only" → `context/decisions/` + `context/product/` + `context/priorities/`
- "Justin joined as lead engineer" → `context/team/` + potentially `context/priorities/` if it unblocks something

When in doubt, write to both and let @draft-learner merge intelligently.

---

## Step 3 — Explicit tag routing

If a structured tag was provided, skip classification and route directly:

| Tag | Destination |
|-----|-------------|
| `[decision]` | `context/decisions/{slug}.md` |
| `[priority]` | `context/priorities/index.md` + log |
| `[product]` | `context/product/index.md` + log |
| `[company]` | `context/company/index.md` + log |
| `[team]` | `context/team/index.md` + log |
| `[memory]` or `[pref]` or `[vocab]` | `memory/memory.md` |

---

## Step 4 — Delegate to @draft-learner

Pass a complete, self-contained brief. Do not pass raw user words — synthesize first. Include:

1. **What was learned** — the synthesized content (what happened, what changed, why if known)
2. **Classification** — which type it is
3. **Destination(s)** — exact file paths to update, with log entries noted where required
4. **Log entry needed?** — yes for `product/`, `priorities/`, structural `company/` or `team/` changes; no for `memory/memory.md` or `user/`
5. **Source** — `user conversation | /learn`
6. **Today's date** — for `last_updated` and log timestamps

Tell @draft-learner to read existing files before writing, merge into current content (never blindly overwrite), and return which files were updated.

**For decisions specifically**, instruct @draft-learner to:
- Create `context/decisions/{slug}.md` with the standard decision format (Decision, Rationale, Context sections)
- Use a kebab-case slug derived from the decision topic
- Set `status: active`

---

## Step 5 — Confirm

After @draft-learner returns, confirm to the user in one or two lines:

- What was saved and where
- If a log entry was written, say so

Examples:
> "Saved. Updated `context/priorities/index.md` — marked 'bridge daemon' as dropped. Log entry written."

> "Saved. Created `context/decisions/drop-bridge-daemon.md` and updated `context/product/index.md`. Log entry written."

> "Saved. Added 'curator' to vocabulary in `memory/memory.md`."

Keep it brief. Do not repeat the full content back to the user.

---

## Rules

- Never ask more than one clarifying question
- Prefer inference over asking — only ask if classification is genuinely ambiguous after reading carefully
- Synthesize before writing — derive meaning from what the user said, don't transcribe it verbatim
- Multiple destinations are fine and often correct
- Never write to `context/user/index.md` from /learn — user context is set via /setup only
- The description field in each index.md is loaded every session — update it to reflect the new reality, not just append to it
