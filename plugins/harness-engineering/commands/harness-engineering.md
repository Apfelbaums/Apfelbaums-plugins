---
name: harness-engineering
description: Use for any query involving CLAUDE.md, AGENTS.md, .cursorrules, or making a codebase work with AI coding agents. Three modes - Audit (evaluate harness maturity), Apply (add specific harness elements), Bootstrap L2 (fully automated - scan codebase, generate all missing artifacts, present for approval). Trigger on creating/fixing CLAUDE.md, architecture linters, reference examples, assessing repo agent-readiness, bootstrapping harness in a project, or "bring this repo to L2". Do NOT use for general CI debugging, Docker setup, or project reviews unrelated to AI agents.
---

# Harness Engineering

Make repositories work as operating systems for AI agents. Core principle: **enforce boundaries mechanically, allow autonomy locally**.

Read `references/harness-guide.md` for the full playbook. This skill tells you HOW to apply it.

## Two Modes

### Mode 1: Audit

When the user asks to assess, audit, or evaluate a repo's agent-readiness.

**Steps:**

1. **Scan the repo** for harness artifacts:
   - `CLAUDE.md` / `AGENTS.md` / `.cursorrules` — instruction files
   - `.pre-commit-config.yaml` — local hooks
   - `.github/workflows/` or CI config — CI pipeline
   - `docs/ARCHITECTURE.md` or `ARCHITECTURE.md` — architecture docs
   - `docs/examples/` — reference examples
   - `docs/adr/` — architecture decision records
   - Linter configs (`ruff.toml`, `.eslintrc`, `dependency-cruiser`)
   - Test coverage setup

2. **Evaluate each L1 item** (read L1 Checklist in harness-guide.md):
   - Does CLAUDE.md exist? Is it <2000 tokens? Does it have commands, architecture rules, MUST/MUST NOT conventions?
   - Are pre-commit hooks set up? Do they include secret scanning?
   - Is there a self-review checklist or four-phase workflow?
   - Are there reference examples?
   - Are permission boundaries defined?

3. **Evaluate L2 items** (read L2 Checklist):
   - Custom linters in CI enforcing architecture?
   - ARCHITECTURE.md with domain map?
   - ADRs for key decisions?
   - Boundary validation (Zod/Pydantic) at API?
   - Continuation context?
   - Testing strategy documented?
   - Feedback loop operational?

4. **Evaluate L3 items** (read L3 Checklist):
   - LoopAgent pattern?
   - Multi-agent coordination?
   - Metrics dashboard?
   - Doc-gardener?

5. **Produce the audit report:**

```markdown
# Harness Audit: [repo-name]

## Current Level: L[1/2/3] (partial/full)

## Score by Category

| Category | Score | Notes |
|----------|-------|-------|
| CLAUDE.md | ⬤/◯ | [status] |
| Pre-commit hooks | ⬤/◯ | [status] |
| CI linters | ⬤/◯ | [status] |
| Architecture docs | ⬤/◯ | [status] |
| Reference examples | ⬤/◯ | [status] |
| Permission boundaries | ⬤/◯ | [status] |

## What's Working
- [item]: [evidence from actual files]

## Gaps (prioritized)

### Critical (blocks agent effectiveness)
- [gap]: [what's missing] → [specific action with file path]

### Important (improves quality)
- [gap]: [what's missing] → [specific action]

### Nice to Have (L2/L3 maturity)
- [gap]: [what's missing] → [specific action]

## Recommended Next Steps
1. [highest-impact action first]
2. ...
```

### Mode 2: Apply

When the user asks to improve, fix, implement, or add harness elements.

**Steps:**

1. **Read the relevant section** from `references/harness-guide.md` — don't improvise, follow the guide's patterns and examples.

2. **Check existing state** — read current files before modifying. Don't overwrite working conventions.

3. **Apply changes** following the guide's templates and anti-patterns table. Key rules:
   - CLAUDE.md must stay under 2000 tokens. Link to docs, don't inline.
   - Commands section: every command must be a copy-pasteable one-liner (not a description).
   - Use MUST/MUST NOT language, not suggestions. "Always" and "should" are too weak.
   - Linters must include per-violation remediation messages (not just "fix your imports").
   - Linters should use a `KNOWN_EXCEPTIONS` set for intentional violations (lifespan wiring, service locators).
   - Follow the rollout strategy: advisory first if violations exist, promote to mandatory after fixing.
   - Reference examples should include negative examples ("use this, not that").

4. **Verify** — after changes, confirm the repo can still build/test/lint.

### Mode 3: Bootstrap L2

When the user asks to "bootstrap", "set up harness", "bring to L2", or simply invokes this skill in a repo without harness.

**This is fully automated.** Agent scans the codebase, generates all missing L2 artifacts, and presents them for approval.

**Steps:**

1. **Scan what exists** — check for CLAUDE.md, ARCHITECTURE.md, .pre-commit-config.yaml, docs/, .github/workflows/, linter configs, test setup. Also check for AGENTS.md / .cursorrules (will be consolidated into CLAUDE.md).

2. **Understand the codebase** — read key files to determine:
   - Tech stack (languages, frameworks, package manager)
   - Directory structure and layers
   - Import patterns and dependency direction
   - Existing conventions (naming, testing, formatting)
   - Build/test/lint commands (check package.json, Makefile, pyproject.toml, etc.)
   - Deploy setup (Docker, Railway, CI)

3. **Generate missing artifacts** — create each missing file following the guide:

   **CLAUDE.md** (if missing or needs rewrite):
   - Extract real commands from package.json/Makefile/pyproject.toml
   - Summarize actual architecture from directory structure
   - Derive MUST/MUST NOT from existing linter rules + observed patterns
   - Add permissions, workflow, Definition of Done
   - MUST stay under 2000 tokens — link to docs/ for details
   - If AGENTS.md or .cursorrules exist, consolidate their content into CLAUDE.md and flag old files for removal

   **ARCHITECTURE.md** (if missing):
   - Map actual layers from directory structure
   - Document real import direction from code analysis
   - List domains/modules with one-line descriptions
   - Add cross-cutting concerns (auth, logging, config)
   - Include Mermaid or ASCII diagram

   **.pre-commit-config.yaml** (if missing):
   - Match stack: ruff for Python, eslint/prettier for JS/TS
   - Always include: detect-private-key, check-merge-conflict, trailing-whitespace
   - Add lint + format hooks matching existing tooling
   - Keep hooks fast (< 30 seconds)

   **docs/examples/** (if missing or empty):
   - Find the best existing code patterns in the repo
   - Create 1-2 reference examples (e.g., new-endpoint.md, new-test.md)
   - Include negative examples ("use this, not that")

   **docs/adr/** (if missing):
   - Create docs/adr/README.md with template
   - If obvious architectural decisions exist (DB choice, framework, auth strategy), create initial ADRs

   **docs/plans/** (if missing):
   - Create directory structure only

4. **Present all changes for approval** — show a summary:
   ```
   ## Bootstrap L2: [repo-name]

   ### Files to create:
   - CLAUDE.md (N tokens) — [brief summary]
   - ARCHITECTURE.md — [layers identified]
   - .pre-commit-config.yaml — [N hooks]
   - docs/examples/new-endpoint.md
   - docs/adr/README.md

   ### Files to consolidate:
   - AGENTS.md → merged into CLAUDE.md (delete AGENTS.md)
   - .cursorrules → [keep/merge decision]

   ### Existing files preserved:
   - [list of files NOT touched]

   Approve to apply all changes?
   ```

5. **Apply on approval** — write all files, verify build/test/lint still pass.

6. **Post-bootstrap checklist:**
   - [ ] `git add` new files, commit with message `chore: bootstrap L2 harness`
   - [ ] Verify pre-commit hooks work: `pre-commit run --all-files`
   - [ ] Verify CLAUDE.md is under 2000 tokens
   - [ ] All internal links resolve

## Anti-Patterns to Avoid

Read the full anti-patterns table in `references/harness-guide.md`. The critical ones:

- Don't write a long CLAUDE.md — keep it to 1-2 screens
- Don't enforce style preferences — only correctness and architecture
- Don't write linters without remediation messages
- Don't skip advisory phase for linters with existing violations
- Don't treat agent errors as model failures — they signal missing harness constraints
