# Claude Code Hooks Catalog

Hook templates for harness engineering. Each hook includes detection criteria, cost tier, and ready-to-use code.

## Hook Conventions

- Exit 0 = allow, exit 2 = block (with guidance message to stderr)
- Use `/tmp/` marker files for cross-hook state, include `$SESSION_ID` for isolation
- Timeout: 10s for PreToolUse, no timeout for PostToolUse
- All hooks read JSON from stdin: `{ "tool_name": "...", "tool_input": { ... } }`

---

## Category 1: Task Discipline

**Tier:** Recommended (free)
**Auto-detect:** Task tracker detected (Linear, Jira, GitHub Issues — look for config files, CLAUDE.md references, or `.linear/` / `.jira/` / `.github/ISSUE_TEMPLATE/`)
**User question:** "Do you use a task tracker? Which one?" (Linear / Jira / GitHub Issues / None)

### 1.1 enforce-task-before-edit

**Lifecycle:** PreToolUse (matcher: Edit, Write)
**What:** Blocks file edits unless the session has an active task.
**Cost:** Free — just checks a marker file.

```bash
#!/bin/bash
# PreToolUse:Edit,Write — Block edits without an active task.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]] && exit 0

# Check for task marker
MARKER="/tmp/active-task-${SESSION_ID:-default}"
[[ -f "$MARKER" ]] && exit 0

echo "BLOCKED: No active task for this session." >&2
echo "Create or claim a task before editing files:" >&2
echo "  {{TASK_CREATE_COMMAND}}" >&2
echo "  {{TASK_CLAIM_COMMAND}}" >&2
exit 2
```

**Placeholders:**
- `{{TASK_CREATE_COMMAND}}` — e.g., `linear-cli issues create "Title"`, `gh issue create -t "Title"`
- `{{TASK_CLAIM_COMMAND}}` — e.g., `linear-cli issues update PROJ-N --state "In Progress"`

### 1.2 session-start-tasks

**Lifecycle:** SessionStart
**What:** Shows task board at session start for context.
**Cost:** Free — one CLI call.

```bash
#!/bin/bash
# SessionStart — Show active tasks for context.

echo "## Active Tasks"
{{TASK_LIST_COMMAND}} 2>/dev/null || echo "(Could not fetch tasks)"
```

**Placeholders:**
- `{{TASK_LIST_COMMAND}}` — e.g., `linear-cli issues list --team MyTeam --state "In Progress"`, `gh issue list --assignee @me`

### 1.3 validate-completion

**Lifecycle:** SubagentStop
**What:** Reminds about open tasks when a subagent finishes.
**Cost:** Free — checks marker file.

```bash
#!/bin/bash
# SubagentStop — Remind about open tasks.

MARKER="/tmp/active-task-${SESSION_ID:-default}"
[[ ! -f "$MARKER" ]] && exit 0

TASK_ID=$(cat "$MARKER")
echo "Subagent finished. Active task: $TASK_ID" >&2
echo "If work is done, close the task: {{TASK_CLOSE_COMMAND}}" >&2
exit 0
```

---

## Category 2: Quality Gates

**Tier:** Optional (medium cost — invokes additional skill passes)
**Auto-detect:** Has git remote (for push hooks), has docs/ directory (for docs hooks)
**User question:** "Do you want code review and simplify passes enforced before every push? This adds ~15-30% token cost per session."
**Consent:** Tier 2 — explicit agreement with cost warning required.

### 2.1 enforce-review-before-push

**Lifecycle:** PreToolUse (matcher: Bash)
**What:** Blocks `git push` unless code review skill was run for current HEAD.
**Cost:** Medium — triggers a full code review pass if not done.

```bash
#!/bin/bash
# PreToolUse:Bash — Block git push without code review.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

echo "$COMMAND" | grep -qE '\bgit\s+push\b' || exit 0

# Check review marker
MARKER="/tmp/code-review-done-commit"
[[ ! -f "$MARKER" ]] && {
  echo "BLOCKED: Run code review before pushing." >&2
  echo "Use /requesting-code-review or your review workflow first." >&2
  exit 2
}

REVIEW_SHA=$(cat "$MARKER")
CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null)

# Allow if reviewed commit is current or very close (≤2 fixup commits)
if [[ "$REVIEW_SHA" != "$CURRENT_SHA" ]]; then
  COMMITS_SINCE=$(git rev-list --count "$REVIEW_SHA".."$CURRENT_SHA" 2>/dev/null || echo 999)
  if [[ "$COMMITS_SINCE" -gt 2 ]]; then
    echo "BLOCKED: Code review is stale ($COMMITS_SINCE commits since review)." >&2
    echo "Run code review again before pushing." >&2
    exit 2
  fi
fi

exit 0
```

### 2.2 enforce-simplify-before-push

**Lifecycle:** PreToolUse (matcher: Bash)
**What:** Blocks `git push` if simplify wasn't run on large diffs (≥20 lines changed).
**Cost:** Medium — triggers simplify pass on large diffs.

```bash
#!/bin/bash
# PreToolUse:Bash — Block git push without simplify on large diffs.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

echo "$COMMAND" | grep -qE '\bgit\s+push\b' || exit 0

# Calculate diff size
BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)
[[ -z "$BASE" ]] && exit 0

DIFF_LINES=$(git diff --stat "$BASE"..HEAD | tail -1 | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | grep -oE '[0-9]+' | paste -sd+ | bc 2>/dev/null || echo 0)
[[ "$DIFF_LINES" -lt 20 ]] && exit 0

# Check simplify marker
MARKER="/tmp/simplify-done-commit"
[[ ! -f "$MARKER" ]] && {
  echo "BLOCKED: Run /simplify before pushing ($DIFF_LINES lines changed)." >&2
  exit 2
}

exit 0
```

### 2.3 enforce-docs-before-close

**Lifecycle:** PreToolUse (matcher: Bash)
**What:** Blocks task close commands unless /project-documentation was run.
**Cost:** Low — just checks a marker file.

```bash
#!/bin/bash
# PreToolUse:Bash — Block task close without documentation update.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Match task close commands (adapt pattern to your tracker)
echo "$COMMAND" | grep -qE '{{TASK_CLOSE_PATTERN}}' || exit 0

MARKER="/tmp/project-docs-done-${SESSION_ID:-default}"
[[ -f "$MARKER" ]] && exit 0

echo "BLOCKED: Run /project-documentation before closing the task." >&2
echo "This ensures documentation stays up to date with code changes." >&2
exit 2
```

**Placeholders:**
- `{{TASK_CLOSE_PATTERN}}` — regex matching close commands, e.g., `tasks close|linear-cli.*--state.*Done`

### 2.4 review-round-tracker

**Lifecycle:** PostToolUse (matcher: Skill)
**What:** Tracks code review rounds and limits them by diff size to prevent infinite review loops.
**Cost:** Free — just tracks state.

```bash
#!/bin/bash
# PostToolUse — Track review rounds, limit by diff size.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL_NAME" != "Skill" ]] && exit 0

# Only track review skill invocations
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
echo "$SKILL" | grep -qi "review" || exit 0

STATE="/tmp/review-rounds-${SESSION_ID:-default}"
ROUND=$(cat "$STATE" 2>/dev/null || echo 0)
ROUND=$((ROUND + 1))
echo "$ROUND" > "$STATE"

# Determine max rounds by diff size
BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)
DIFF_LINES=$(git diff --stat "$BASE"..HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1 || echo 0)

if [[ "$DIFF_LINES" -lt 100 ]]; then
  MAX=1
elif [[ "$DIFF_LINES" -lt 300 ]]; then
  MAX=2
else
  MAX=3
fi

if [[ "$ROUND" -ge "$MAX" ]]; then
  echo "Review round $ROUND/$MAX (final). Focus on CRITICAL issues only." >&2
fi

exit 0
```

---

## Category 3: Domain Reminders

**Tier:** Recommended (free)
**Auto-detect:** Directories with their own CLAUDE.md, README.md with guidelines, or checklist files.
**No user question needed.**

### 3.1 domain-checklist-reminder

**Lifecycle:** PreToolUse (matcher: Write)
**What:** Non-blocking reminder when editing files in directories that have domain-specific guidelines.
**Cost:** Free — just prints a message.

```bash
#!/bin/bash
# PreToolUse:Write — Remind about domain-specific guidelines.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL_NAME" != "Write" ]] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

# Check each configured domain
{{DOMAIN_CHECKS}}

exit 0
```

**Template for each domain (generated during bootstrap):**
```bash
# Example: legal/ directory
if echo "$FILE_PATH" | grep -q "^.*/legal/"; then
  echo "Reminder: Working in legal/ — check legal-analysis-checklist.md for required frontmatter and source links." >&2
fi

# Example: docs/ directory
if echo "$FILE_PATH" | grep -q "^.*/docs/"; then
  echo "Reminder: Working in docs/ — validate all internal links before committing." >&2
fi
```

---

## Category 4: Safety Guards

**Tier:** Recommended (free)
**Auto-detect:** Always (block-dangerous-commands), or based on repo features.
**No user question needed.**

### 4.1 block-dangerous-commands

**Lifecycle:** PreToolUse (matcher: Bash)
**What:** Blocks destructive commands that are almost never intentional.
**Cost:** Free.

```bash
#!/bin/bash
# PreToolUse:Bash — Block dangerous commands.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Force push to main/master
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force.*\b(main|master)\b|git\s+push\s+.*\b(main|master)\b.*--force'; then
  echo "BLOCKED: Force push to main/master is not allowed." >&2
  echo "Create a branch and open a PR instead." >&2
  exit 2
fi

# Destructive rm
if echo "$COMMAND" | grep -qE 'rm\s+-rf\s+/\s|rm\s+-rf\s+/[^.]'; then
  echo "BLOCKED: Destructive rm -rf on root paths is not allowed." >&2
  exit 2
fi

# DROP DATABASE
if echo "$COMMAND" | grep -qiE 'DROP\s+(DATABASE|SCHEMA)\b'; then
  echo "BLOCKED: DROP DATABASE/SCHEMA is not allowed via agent." >&2
  echo "Run destructive database operations manually." >&2
  exit 2
fi

exit 0
```

### 4.2 enforce-no-skip-hooks

**Lifecycle:** PreToolUse (matcher: Bash)
**What:** Blocks `--no-verify` to prevent skipping pre-commit hooks.
**Auto-detect:** Has `.pre-commit-config.yaml` or git hooks in `.git/hooks/`.
**Cost:** Free.

```bash
#!/bin/bash
# PreToolUse:Bash — Block --no-verify flag.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

echo "$COMMAND" | grep -qE '\-\-no-verify\b' || exit 0

echo "BLOCKED: --no-verify is not allowed." >&2
echo "Pre-commit hooks exist for a reason. Fix the issue instead of bypassing." >&2
exit 2
```

### 4.3 block-manual-deploy

**Lifecycle:** PreToolUse (matcher: Bash)
**What:** Blocks manual deploy commands; all deploys go through CI.
**Auto-detect:** Has CI pipeline (`.github/workflows/`, `.gitlab-ci.yml`, `railway.json`, `fly.toml`).
**Cost:** Free.

```bash
#!/bin/bash
# PreToolUse:Bash — Block manual deploy commands.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Match common manual deploy commands (customize per project)
if echo "$COMMAND" | grep -qE '\b(railway up|fly deploy|vercel --prod|kubectl apply)\b'; then
  echo "BLOCKED: Manual deploys are not allowed." >&2
  echo "All deploys go through git push + CI pipeline." >&2
  exit 2
fi

exit 0
```

---

## Category 5: Session Hygiene

**Tier:** Optional (free-low)
**Auto-detect:** Always available.
**User question:** "Want session hygiene hooks? They warn about context bloat and remind you to capture learnings." (Yes/No)

### 5.1 context-size-warning

**Lifecycle:** PostToolUse
**What:** Warns at regular intervals about growing context size.
**Cost:** Free.

```bash
#!/bin/bash
# PostToolUse — Warn about context size growth.

STATE="/tmp/turn-count-${SESSION_ID:-default}"
COUNT=$(cat "$STATE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$STATE"

# Warn every 20 turns
[[ $((COUNT % 20)) -ne 0 ]] && exit 0

if [[ "$COUNT" -ge 100 ]]; then
  echo "CRITICAL: $COUNT turns in this session. Context is very large." >&2
  echo "Consider starting a new session or running context cleanup." >&2
elif [[ "$COUNT" -ge 60 ]]; then
  echo "WARNING: $COUNT turns in this session. Context is growing." >&2
  echo "Consider wrapping up current work soon." >&2
fi

exit 0
```

### 5.2 reflect-reminder

**Lifecycle:** Stop
**What:** Reminds to capture learnings at session end.
**Cost:** Free.

```bash
#!/bin/bash
# Stop — Remind to capture learnings before ending session.

# Only remind once per session
LOCK="/tmp/reflect-reminded-${SESSION_ID:-default}"
[[ -f "$LOCK" ]] && exit 0
touch "$LOCK"

echo "Session ending. Consider capturing any learnings or patterns from this session." >&2
exit 0
```

---

## Bootstrap Integration

### Detection Logic

During codebase scan, check for:

| Signal | Detected by | Unlocks |
|--------|-------------|---------|
| Task tracker | `linear-cli` in CLAUDE.md, `.linear/`, `.github/ISSUE_TEMPLATE/`, Jira config | Category 1 (Task Discipline) |
| Git remote | `git remote -v` output | Category 2 (Quality Gates) |
| Domain guidelines | Subdirectories with own CLAUDE.md/README.md/checklist files | Category 3 (Domain Reminders) |
| Pre-commit hooks | `.pre-commit-config.yaml`, `.git/hooks/` | 4.2 (enforce-no-skip-hooks) |
| CI pipeline | `.github/workflows/`, `.gitlab-ci.yml`, `railway.json`, `fly.toml` | 4.3 (block-manual-deploy) |
| Always | — | 4.1 (block-dangerous-commands), Category 5 |

### Question Flow

```
1. [If task tracker detected] "You use {{TRACKER}}. Want task enforcement hooks
   that block edits without an active task?" [Y/n]

2. [If git remote exists] "Want quality gate hooks (code review + simplify before push)?
   ⚠️ These add ~15-30% token cost per session." [Y/n/details]

3. "Want session hygiene hooks (context size warnings, learnings reminders)?" [Y/n]
```

### Consent Display

```
## Recommended hooks (no extra token cost):
{{LIST_OF_RECOMMENDED_HOOKS}}

Enable all recommended hooks? [Y/n]

## Optional hooks (increase token usage ~15-30% per session):
{{LIST_OF_OPTIONAL_HOOKS_WITH_DESCRIPTIONS}}

These hooks improve quality but consume additional tokens.
Enable optional hooks? [Y/n/pick individually]
```

### Output

Generated hooks are placed in `.claude/hooks/` (project-level) and registered in `.claude/settings.json` under the project's hooks section.
