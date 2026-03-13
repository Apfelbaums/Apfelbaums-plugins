---
name: project-documentation
description: Use after completing any task that changes code, infrastructure, services, or workflows. Works in ANY project — detects project type and runs the right post-task checklist. Keeps existing docs current. Does NOT create harness structure from scratch — use /harness-engineering for that.
---

# Project Documentation

Keep docs current after every task. Stale docs are worse than no docs.

**Scope**: This skill is a **post-task checklist** — it ensures existing documentation reflects what just changed. It does NOT set up documentation structure, create templates, or audit harness maturity — that's `/harness-engineering`.

## Step 1: Detect Project Type

```
Does the repo contain application source code (src/, app/, lib/, frontend/, backend/)?
  → CODEBASE

Is it a knowledge base, vault, or command center (docs/, scripts/, no app code)?
  → COMMAND CENTER

Not sure?
  → CODEBASE (default)
```

---

## Codebase Post-Task Checklist

After completing ANY task in a codebase project, run through this. Every item is yes/no — if yes, make the update.

### 1. Architecture changed?
Did you add a new layer, module, change boundaries, or make a significant design decision?
→ Update `ARCHITECTURE.md`
→ If it's a significant decision, add `docs/adr/NNN-decision-name.md`

### 2. New pattern established?
Did you create a new way of doing something (new endpoint, test, component pattern)?
→ Add or update `docs/examples/`

### 3. Infrastructure or deployment changed?
Docker, CI, hosting, env vars, ports, domains?
→ Update relevant doc in `docs/`
→ Update `CLAUDE.md` Commands if commands changed

### 4. API or integration changed?
Endpoints added/removed/modified, external integrations, webhooks?
→ Update relevant doc in `docs/`

### 5. New convention discovered?
Agent error revealed a missing constraint? Found a footgun?
→ Add MUST/MUST NOT rule to `CLAUDE.md`

### 6. New doc file created?
→ Ensure it's linked from `CLAUDE.md` or an index file — orphan docs are invisible

### 7. Plan work?
Started or completed significant work?
→ Create/move plan in `docs/plans/`

### 8. Cross-project dependencies?
Did this change affect related projects or shared libraries?
→ Update affected projects:
```bash
# Example: if you have a monorepo, shared library, or command center
cd /path/to/related-project && git pull
# Update relevant docs (PROJECTS.md, INFRASTRUCTURE.md, API.md, etc.)
./scripts/sync.sh && cd -  # if applicable
```

### 9. Verify links
If you updated any doc:
→ Check that all internal links `[text](path)` point to existing files

---

## Command Center Post-Task Checklist

For knowledge repos, vaults, and command centers without application code.

### 1. Infrastructure changes?
Server config, Docker, ports, network, firewall, auth?
→ Update `docs/INFRASTRUCTURE.md`

### 2. Service or API changes?
MCP servers, APIs, integrations, tools?
→ Update `docs/SERVICES.md`

### 3. Project changes?
New project, status change, repo rename, deprecation?
→ Update `docs/PROJECTS.md`

### 4. Agent changes?
Agent config, model, workspace, tools?
→ Update `docs/AGENTS.md`

### 5. Workflow changes?
New rule, convention change, task management?
→ Update `docs/WORKFLOWS.md`

### 6. New command or script?
→ Update `CLAUDE.md` Commands section

### 7. New doc file?
→ Update `CLAUDE.md` Navigation table

### 8. Plan work?
→ Create/move plan in `docs/plans/active/` or `docs/plans/completed/`

### 9. Verify links
→ Check that all internal links point to existing files

---

## Anti-patterns

- Putting project facts in memory/ instead of docs/
- CLAUDE.md over 2000 tokens — move detail to docs/, keep a link
- Creating docs without linking them from CLAUDE.md or an index
- Leaving completed plans in `active/` — move to `completed/`
- Skipping docs update because "it's a small change" — they accumulate
