# Project Documentation

Post-task documentation checklist. Keeps docs current after every code or infrastructure change.

## Problem

Stale docs are worse than no docs. After implementing features, fixing bugs, or changing infrastructure, documentation often gets forgotten. This skill ensures docs stay synchronized with reality.

## What It Does

**This is a checklist, not a generator.** It doesn't create documentation from scratch — it ensures existing docs reflect what just changed.

After completing ANY task, the skill:
1. Detects your project type (codebase vs command center)
2. Runs the appropriate post-task checklist
3. Prompts you to update relevant docs

## Usage

```bash 
/project-documentation
```

The skill will:
1. Auto-detect project type
2. Present a yes/no checklist
3. Guide you to update only what changed

## Project Types

### Codebase Projects
Repositories with application code (`src/`, `app/`, `lib/`, `frontend/`, `backend/`)

**Checklist covers:**
- Architecture changes → `ARCHITECTURE.md`, `docs/adr/`
- New patterns → `docs/examples/`
- Infrastructure changes → `docs/`, `CLAUDE.md`
- API changes → API docs
- Conventions → `CLAUDE.md` MUST/MUST NOT rules
- Plans → `docs/plans/`
- Cross-project dependencies

### Command Center Projects
Knowledge repos, vaults, command centers (`docs/`, `scripts/`, no app code)

**Checklist covers:**
- Infrastructure → `docs/INFRASTRUCTURE.md`
- Services → `docs/SERVICES.md`
- Projects → `docs/PROJECTS.md`
- Agents → `docs/AGENTS.md`
- Workflows → `docs/WORKFLOWS.md`
- Commands → `CLAUDE.md`

## Example Workflow

**Scenario:** You just added a new API endpoint with rate limiting.

1. Run `/project-documentation`
2. Checklist prompts:
   - ✅ Architecture changed? → Update `ARCHITECTURE.md` (new rate-limiting layer)
   - ✅ New pattern? → Add `docs/examples/rate-limited-endpoint.md`
   - ✅ API changed? → Update API docs
   - ✅ New convention? → Add to `CLAUDE.md`: "MUST use rate limiter for all public endpoints"
   - ❌ Infrastructure changed? → No
   - ❌ Cross-project impact? → No
3. Update the relevant docs
4. Verify all internal links work

## Anti-Patterns (What NOT to Do)

- ❌ Putting project facts in `memory/` instead of `docs/`
- ❌ CLAUDE.md over 2000 tokens — move details to `docs/`, keep links
- ❌ Creating docs without linking from `CLAUDE.md` or index (orphan docs)
- ❌ Leaving completed plans in `active/` — move to `completed/`
- ❌ Skipping updates because "it's a small change" — they accumulate

## When to Use

Use this skill **after** completing:
- New features
- Bug fixes
- Infrastructure changes
- API modifications
- Architecture decisions
- Workflow changes

## When NOT to Use

This skill does NOT:
- Create documentation structure from scratch (use `/harness-engineering` for that)
- Write documentation for you (it's a checklist, not a generator)
- Audit documentation quality (use `/harness-engineering` Audit mode)

## Integration with Harness Engineering

This skill works best with a proper harness structure:
- Use `/harness-engineering` to set up `CLAUDE.md`, `ARCHITECTURE.md`, `docs/` structure
- Use `/project-documentation` after every task to keep docs current

## License

MIT
