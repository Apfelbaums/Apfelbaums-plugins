# Harness Engineering Guide

Unified playbook for making repositories agent-friendly. Based on OpenAI's Codex harness, arXiv research, and production experience.

Core principle: **enforce boundaries mechanically, allow autonomy locally**. The repository is an operating system for agents. You care about correctness and architecture — not stylistic preferences.

> OpenAI's Codex team: 1M+ LOC, zero lines written by humans, ~1,500 PRs in 5 months. The harness, not the prompt, is the primary lever for scale.

---

## Maturity Model

| Level | Name | What | When |
|-------|------|------|------|
| **L1** | Basic Harness | CLAUDE.md, pre-commit hooks, test suite, self-review checklist | Day 1 — every repo |
| **L2** | Team Harness | Custom linters in CI, architecture docs, continuation context, testing strategy | Week 2 — active development |
| **L3** | Full Autonomy | Multi-agent coordination, doc-gardeners, metrics, LoopAgent patterns | Month 2 — high-velocity repos |

Start at L1. Promote incrementally. Never skip levels.

---

## Foundational Principles

### Hierarchy of truth sources

Higher levels override lower. Promote rules upward whenever possible:

| Level | What | Example | Priority |
|-------|------|---------|----------|
| 1. Enforcement | CI, linters, tests | `make lint` fails on violation | Highest |
| 2. Policy | CLAUDE.md | "MUST NOT import routes from models" | High |
| 3. Architecture | ARCHITECTURE.md, ADRs | Module boundaries, data flow diagrams | Medium |
| 4. Operations | Runbooks, deploy docs | How to rollback, debug, monitor | Lower |
| 5. Reference | Example PRs, tests | "Here's what a good endpoint looks like" | Lowest |

If a rule can be enforced automatically (level 1), don't rely on documentation (level 2-5).

### Agent legibility as north star

From the agent's POV, anything it cannot access in-context does not exist. Knowledge in Slack/Google Docs is invisible. Repository-first knowledge, progressive disclosure, and machine-checkable documents outperform chatty context dumps.

### MUST / MUST NOT language

Agents ignore suggestions but follow constraints. The shorter the constraint, the more reliably it's followed:

```markdown
# Bad — vague, ignorable
- Follow project conventions
- Keep code clean

# Good — specific, enforceable
- MUST run `make lint` before pushing. Fix ALL errors.
- MUST NOT import from `app/routes/` in model files.
- MUST NOT commit files containing API keys or secrets.
```

### Context minimalism

Less context beats more. arXiv research (2602.11988v1): over-specified context files reduce task success rates by 20%+ and increase inference costs. CLAUDE.md = **map, not encyclopedia**. Max 1-2 screens (<2000 tokens). Link to docs, don't inline.

### Permission boundaries

Explicitly define what agents can do without approval vs what requires human confirmation:

```markdown
## Permissions
- WITHOUT approval: read files, run tests, run linters, create branches
- REQUIRES approval: install packages, git push, delete files, modify CI
```

---

## L1: Basic Harness

**Time: 1-2 hours. Every repo that agents touch.**

### 1. CLAUDE.md

Every repo needs a CLAUDE.md at the root. First thing the agent reads. Contains:

#### 1.1 Build & test commands

```markdown
## Commands
- Install: `npm install` / `pip install -e .`
- Run: `npm run dev` / `python -m app`
- Test all: `npm test` / `pytest`
- Test one: `npm test -- path/to/test` / `pytest path/to/test.py`
- Lint: `npm run lint` / `ruff check .`
- Format: `npx prettier --write .` / `ruff format .`
```

Agents waste enormous context discovering how to build and test. Spell it out.

#### 1.2 Architecture rules

Define the dependency direction:

```markdown
## Architecture
Layers (dependency flows top to bottom only):
1. **Types/Models** — data shapes, no imports from other layers
2. **Repository/Data** — database access, imports only Types
3. **Services** — business logic, imports Types + Repository
4. **API/Routes** — HTTP handlers, imports Services only
5. **UI** — templates/components, imports API types only

Do NOT import Services from Repository. Do NOT import Repository from API.
```

#### 1.3 Conventions (MUST/MUST NOT)

```markdown
## Conventions
- MUST use `{ data, error, meta }` envelope for all API responses.
- MUST use snake_case for database columns, camelCase for API fields.
- MUST prefix environment variables with `APP_`. MUST NOT hardcode secrets.
- MUST NOT exceed 500 lines per file or 50 lines per function.
- MUST use structured logging with `request_id` in every log entry.
```

#### 1.4 What NOT to put in CLAUDE.md

- Onboarding guides for humans (install Docker, set up IDE)
- History or changelog
- Anything that changes weekly — keep it stable
- Entire style guides — use linters instead

#### 1.5 Instruction files across tools

| Tool | File | Scope | Best Practice |
|------|------|-------|---------------|
| Claude Code | `CLAUDE.md` | Project root + subdirs. Checked first. | 100-200 lines, <2000 tokens |
| Cursor | `.cursorrules` / `.mdc` | Glob patterns for file-scoped rules | Under 500 lines |
| Generic / Codex | `AGENTS.md` | Universal fallback | ~100 lines, table of contents |

### 2. Pre-Commit Hooks

Fast, file-scoped checks that run locally:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - id: detect-private-key      # Secret scanning
      - id: check-merge-conflict
      - id: trailing-whitespace
  - repo: local
    hooks:
      - id: lint
        name: lint
        entry: make lint
        language: system
        pass_filenames: false
```

Include: secret scanning, formatting, type checking.
Keep local hooks **advisory** — CI is the source of truth.

### 3. Self-Review Checklist

Add to CLAUDE.md or workflow instructions:

```markdown
Before pushing code:
1. Run the full lint suite. Fix ALL failures.
2. Run tests. Fix ALL failures.
3. Review your own diff (`git diff`). Check for:
   - Leftover debug prints or console.log
   - TODO comments you added but didn't resolve
   - Unused imports or variables
   - Hardcoded values that should be config
4. Only push when lint + tests pass and diff looks clean.
```

### 4. Four-Phase Agent Cycle

Structure agent work into explicit phases:

```markdown
## Workflow
A. PLAN — Read issue, explore codebase, identify files, formulate approach. Do NOT write code yet.
B. IMPLEMENT — Write code following the plan. Write tests alongside. Keep changes minimal.
C. VERIFY — Run tests, run linters, review own diff, check requirements match.
D. CORRECT — Fix failures, re-verify. Only create PR when everything passes.
```

### 5. Reference Examples

Create `docs/examples/` with concrete patterns agents can copy:

| Example | Content |
|---------|---------|
| **Good PR** | Title format, description, test plan, linked issue |
| **Unit test** | Setup/teardown, assertion style, naming, edge cases |
| **New endpoint** | Route, validation, service call, error handling, response |
| **Migration** | Naming, rollback strategy, data backfill pattern |

Include **negative examples** ("use this, not that"):

```markdown
# Bad — scattered auth imports
from app.auth.middleware import decode_jwt

# Good — explicit provider
from app.providers import get_current_user
```

### L1 Checklist

- [ ] CLAUDE.md with commands, architecture, conventions (MUST/MUST NOT)
- [ ] CLAUDE.md under 2 screens, links to detailed docs
- [ ] Agent can build, test, and lint from CLAUDE.md alone
- [ ] Pre-commit hooks for secrets and formatting
- [ ] Self-review checklist in agent workflow
- [ ] Four-phase cycle documented
- [ ] At least one reference example in docs/examples/
- [ ] Permission boundaries defined

---

## L2: Team Harness

**Time: 1-2 weeks. For repos with active agent-driven development.**

### 6. Custom Linters in CI

Replace prose with deterministic rules. Block merges on violation.

#### Design principles

1. **Remediation message** — every error tells the agent HOW to fix: "Violation → Why → Fix snippet → Link to example"
2. **One concern per linter** — small, focused checks
3. **Advisory first, mandatory later** — check existing violations before blocking
4. **Agent-generated** — agents can write the linters themselves

#### Universal linters (any language)

| Check | Threshold | Remediation |
|-------|-----------|-------------|
| File size | 500 LOC | "Split into smaller modules. Single responsibility." |
| Function size | 50 LOC | "Extract helper functions or split into steps." |
| TODO count | 30 total | "Resolve or create issues. Don't accumulate debt." |
| Missing docs | 0 undocumented public modules | "Add docstring explaining purpose and usage." |

#### Architecture linters by stack

| Language | Tools | Enforces |
|----------|-------|----------|
| TypeScript | `dependency-cruiser`, `eslint-plugin-boundaries` | Layer edges, cycles, orphan modules |
| Python | `Ruff` / custom Flake8 plugin, pytest structure checks | Import direction, file size limits |
| Go | `golangci-lint` (`depguard`, custom analyzer) | Allowed imports per package |

**TypeScript example** — dependency-cruiser:
```javascript
// .dependency-cruiser.cjs
forbidden: [{
  from: { path: '^src/models' },
  to: { path: '^src/routes' },
  comment: 'Models must not import from routes. Move shared types to src/types/'
}]
```

**Python example** — custom check:
```python
for file in glob("app/models/**/*.py"):
    for line in file:
        if "from app.routes" in line:
            fail(f"{file}: models must not import from routes")
```

#### Rollout strategy

```
1. Write the linter
2. Run against codebase, count violations
3. If violations == 0 → add to CI immediately (mandatory)
4. If violations > 0 → log as advisory, create issue to fix
5. Fix violations (agent can do this)
6. Enable auto-fix where supported (Ruff, ESLint --fix)
7. Promote to mandatory CI block
```

### 7. CI Pipeline Hardening

Local hooks are advisory. CI is truth.

```yaml
# Branch protection rules
- Require status checks to pass before merging
- Require branches to be up to date
- Block --no-verify bypass via server-side pre-receive hooks
```

Use merge queues (Mergify, GitHub merge queue) to ensure PRs are rebased and retested before merge.

### 8. Claude Code Hooks

Beyond git pre-commit hooks, Claude Code supports **session-level hooks** — shell scripts that run at specific lifecycle events (PreToolUse, PostToolUse, SessionStart, Stop, etc.). These enforce workflow discipline inside the agent session itself.

See `references/hooks-catalog.md` for the full catalog with templates.

#### Five categories

| Category | Tier | Cost | Purpose |
|----------|------|------|---------|
| **Task Discipline** | Recommended | Free | Can't edit without active task, show tasks at session start |
| **Quality Gates** | Optional | Medium (+15-30% tokens) | Review/simplify before push, docs before close |
| **Domain Reminders** | Recommended | Free | Context-specific hints when editing certain directories |
| **Safety Guards** | Recommended | Free | Block dangerous commands, --no-verify, manual deploys |
| **Session Hygiene** | Optional | Free | Context size warnings, learnings capture |

#### Bootstrap flow

1. **Auto-detect** — scan for task tracker, CI pipeline, pre-commit hooks, domain guidelines
2. **Ask 2-3 questions** — task tracker type, review workflow preference, session hygiene
3. **Two-tier consent:**
   - Recommended hooks (free) → batch approve
   - Optional hooks (token-costly) → explicit consent with cost warning
4. **Generate** — hook scripts in `.claude/hooks/`, register in `.claude/settings.json`

#### Key rules

- Hooks exit 0 (allow) or exit 2 (block with guidance)
- PreToolUse hooks get 10s timeout
- Marker files in `/tmp/` with `$SESSION_ID` for cross-hook state
- Recommended hooks = safe default. Optional hooks = user must understand the cost
- NEVER auto-enable token-costly hooks without explicit user agreement

### 9. Architecture Documentation

#### ARCHITECTURE.md

Top-level map of domains and package layering. Cross-linked with CLAUDE.md. Keep current.

```markdown
# Architecture

## Domains
- users/ — registration, auth, profiles
- orders/ — order lifecycle, payments
- notifications/ — email, push, webhooks

## Layering
Types → Config → Repository → Service → Runtime → UI
Cross-cutting: providers/ (auth, logging, telemetry)

## Design Documents
- [ADR-001: Database choice](docs/adr/001-database-choice.md)
- [ADR-002: Auth strategy](docs/adr/002-auth-strategy.md)
```

#### ADRs (Architecture Decision Records)

Capture WHY a decision was made. Use MADR template:

```markdown
# ADR-001: Use PostgreSQL for primary storage

## Status: Accepted
## Context: Need ACID transactions, JSON support, mature ecosystem
## Decision: PostgreSQL 16 with pgvector for embeddings
## Consequences: Requires managed instance, team knows SQL
```

Tools: `adr-toolkit` can parse ADR Markdown into machine-readable JSON for CI/PR summaries.

#### Dependency diagrams and drift detection

Generate dependency graphs in CI. Block on violations:
- TypeScript: `dependency-cruiser --output-type dot | dot -T svg`
- Python: `pydeps --no-show src/`

### 10. Structured Boundaries

#### Parse at the boundary

Validate external data at system edges. Inside the boundary, trust types:
- **TypeScript**: Zod schemas at API handlers
- **Python**: Pydantic models at API + config
- **Go**: Validation at handler, typed structs internally

```typescript
// Good: parse at boundary
const UserInput = z.object({ name: z.string(), email: z.email() });
app.post('/users', (req) => {
  const input = UserInput.parse(req.body); // throws if invalid
  return userService.create(input);        // input is typed
});
```

#### Explicit cross-cutting concerns

Auth, logging, telemetry enter through ONE interface:

```
src/providers/
  auth.ts      # get_current_user()
  logging.ts   # log_event()
  telemetry.ts # trace()
```

#### Domain-driven layout

```
src/
  domains/
    users/
      types.ts        # Data shapes
      repository.ts   # Database access
      service.ts      # Business logic
      routes.ts       # API handlers
    orders/
      types.ts
      repository.ts
      service.ts
      routes.ts
  providers/
    auth.ts
    logging.ts
```

When every domain follows the same template, agents know where to add code without guessing.

### 11. Continuation Context

When a session fails or times out, the next attempt must know what was done.

#### Plan checkpoints

```json
// docs/plans/.checkpoint.json
{
  "plan_file": "docs/plans/active/feature-x.md",
  "current_phase": 2,
  "completed_tasks": ["setup-types", "add-repository"],
  "timestamp": "2026-03-07T10:00:00Z"
}
```

#### Retry prompt template

```markdown
{% if attempt %}
This is retry attempt #{{ attempt }}.
- Resume from current workspace state, don't restart from scratch.
- Check `git log` and `git status` for previous session's work.
- If a PR already exists, continue working on it.
{% if retry_reason %}- Previous session ended because: {{ retry_reason }}{% endif %}
{% endif %}
```

#### Idempotency keys

Prevent duplicate PRs by injecting keys into commit trailers:

```
git commit -m "feat: add user service

Idempotency-Key: task-123-attempt-2"
```

Server-side guard: before creating PR, check if one with the same idempotency key exists.

### 12. Testing Strategy

#### TDD prompts

Instruct agents to write tests first or alongside implementation:

```markdown
## Testing
- MUST write test before implementing new feature (red → green → refactor)
- MUST follow Arrange-Act-Assert structure
- MUST cover happy path + at least one error case
- Coverage target: 80%+ for new code
```

#### File-scoped tests for speed

Fast, file-scoped commands for agent feedback loop:
```markdown
- Quick test: `pytest path/to/test_file.py -x` (stop on first failure)
- Quick lint: `ruff check path/to/file.py`
- Full suite: only before push or in CI
```

#### Bootable per worktree

Make the app launchable per git worktree so agents can test in isolation:
- Each worktree gets its own `.env` and database
- Headless browser tests for UI verification

### 13. Feedback Loop

```
Agent writes code
  → Human reviews PR
    → Review comment identifies pattern
      → Pattern encoded as:
         - CLAUDE.md rule (MUST/MUST NOT) — if one-off
         - Linter with remediation — if recurring
         - Reference example — if structural confusion
```

**Key insight: every agent error is a signal that something is missing from the harness.** Don't retry — ask "what constraint, tool, or document is missing?"

When to encode what:
| Signal | Action |
|--------|--------|
| Recurring review comment | Add MUST/MUST NOT to CLAUDE.md |
| Repeated architectural violation | Write linter with remediation message |
| Agent confusion about structure | Add reference example to docs/examples/ |
| Style preference | Only encode if it affects correctness |

### L2 Checklist

- [ ] Architecture linters in CI (import direction enforcement)
- [ ] File/function size linters in CI
- [ ] ARCHITECTURE.md with domain map and layering
- [ ] At least 2 ADRs for key technical decisions
- [ ] Boundary validation (Zod/Pydantic) at API layer
- [ ] Continuation context (checkpoints or retry templates)
- [ ] Testing strategy documented, TDD encouraged
- [ ] Merge queue or branch protection blocking --no-verify
- [ ] Feedback loop: review comments → rules/linters
- [ ] Dependency diagrams generated in CI
- [ ] Claude Code hooks configured (safety guards + workflow enforcement) — see `references/hooks-catalog.md`

---

## L3: Full Autonomy

**Time: ongoing. For repos where agents do most of the coding.**

### 14. Self-Review Loop (Advanced): LoopAgent Pattern

Beyond simple checklists — a Generator-Auditor loop with circuit breakers:

```
┌─────────────┐
│   Drafter    │ ← writes code
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Auditor    │ ← checks against policies
└──────┬──────┘
       │
   Pass? ──yes──→ PR
       │
      no (retry ≤ max_iterations)
       │
       ▼
   Fix + loop back to Drafter
```

**Circuit breaker:** set `max_iterations` (typically 3-5). If auditor keeps failing, escalate to human instead of infinite loop.

### 15. Parallel Review Agents

Spin up parallel subagents for depth:

```
Main Agent
  ├── Test Runner Agent    → run tests, report failures
  ├── Linter Agent         → run all linters
  ├── Security Agent       → scan for vulnerabilities
  └── Performance Agent    → check for N+1, memory leaks
```

Main agent synthesizes all results into prioritized summary. Much faster than sequential review.

### 16. Diff-Aware Retry Templates

Jinja2 templates for context-aware retries:

```markdown
## Retry Context
- **Attempt**: {{ attempt }} of {{ max_attempts }}
- **Previous failures**: {{ failing_tests | join(', ') }}
- **Changed files**: {{ changed_files | join(', ') }}
- **Error logs**: {{ error_summary }}
- **Remaining budget**: {{ max_attempts - attempt }} retries

Focus on fixing: {{ failing_tests[0] }}
```

### 17. Multi-Agent Coordination

#### Orchestration topology

```
Leader (creates team, spawns workers)
  ├── Worker A (own worktree + branch)
  ├── Worker B (own worktree + branch)
  └── Worker C (own worktree + branch)

Shared: Task List (JSON), Inboxes (inter-agent messaging)
```

#### Isolation strategies

Each agent operates in its own git worktree:
```bash
git worktree add -b task/feature-a .worktrees/feature-a
git worktree add -b task/feature-b .worktrees/feature-b
```

Lock-file protocol prevents duplicate work and race conditions.

#### Conflict prevention

1. **Smart task distribution** — map file dependencies, prevent overlapping assignments
2. **Merge queues** — auto-rebase PRs when behind main, re-trigger CI
3. **Rebase bots** — Mergify `queue` action for ordered merging

| Strategy | Solves | Implementation | Tradeoffs |
|----------|--------|----------------|-----------|
| Git worktrees | File conflicts | `git worktree add -b task/...` | Disk space management |
| Shared task list | Duplicate work | JSON with status tracking + locks | Strict lock protocol needed |
| Merge queues | Merge conflicts on main | Mergify / GitHub merge queue | Delays time-to-merge |

### 18. Doc-Gardener Automation

A recurring agent that maintains documentation freshness:

- Scans for stale docs that no longer reflect real code
- Opens fix-up PRs automatically
- Validates links, checks for drift between ARCHITECTURE.md and actual imports
- Runs weekly or on schedule

### 19. Metrics & Dashboards

#### Core KPIs

| Metric | What it measures | Target |
|--------|-----------------|--------|
| PR acceptance rate | Quality of agent output | >80% first-time accept |
| Time-to-merge | Speed of agent workflow | <2 hours for L2+ repos |
| Retry count | Stability of harness | <2 retries per task |
| Lines added/removed | Scope control | Track, don't gate |
| Cost per task | Efficiency | Decreasing over time |

#### Instrumentation

| Source | Metrics | Granularity |
|--------|---------|-------------|
| Claude Code Analytics API | Sessions, PRs, tool acceptance, tokens, cost | Daily/user |
| GitHub Copilot Usage API | PR throughput, time-to-merge | Org-level |
| OpenTelemetry (`claude_telemetry`) | Tool invocations, durations, token use | Per run |

#### Maturity assessment

Use PR acceptance rates by task type to assess maturity:
- Documentation tasks: ~82% acceptance (easiest)
- Bug fixes: ~75% acceptance
- New features: ~66% acceptance (hardest)

If acceptance rate drops, something is missing from the harness.

### 20. Durable Orchestrators

For long-running, multi-step workflows:
- **Temporal Workflows** — automatic state persistence, survives crashes
- **Plan file state machines** — lighter-weight, filesystem-based
- Choose based on complexity: plan files for most, Temporal for mission-critical

### L3 Checklist

- [ ] LoopAgent pattern (Generator-Auditor with circuit breaker)
- [ ] Parallel review agents (test, lint, security, performance)
- [ ] Multi-agent coordination with worktree isolation
- [ ] Doc-gardener running on schedule
- [ ] Metrics dashboard (PR acceptance, time-to-merge, retries, cost)
- [ ] Diff-aware retry templates with budget control
- [ ] Merge queue enforcing rebase + CI re-run
- [ ] Maturity assessment by task type

---

## Anti-Patterns

| Don't | Do instead |
|-------|-----------|
| Refactor entire codebase upfront | Add rules incrementally, fix violations over time |
| Write 50 linters at once | Start with 3-5 universal ones, add as patterns emerge |
| Enforce stylistic preferences | Enforce correctness and architecture only |
| Micromanage implementations | Set boundaries, let agent choose approach |
| Skip advisory phase | Always check existing violations before making mandatory |
| Write linters without remediation | Every error must tell the agent how to fix it |
| Write long CLAUDE.md | Keep to 1-2 screens, link to docs for details |
| Use vague language ("keep clean") | Use MUST/MUST NOT with specific, verifiable constraints |
| Treat agent errors as model failures | Treat as missing constraints in the harness |
| Skip the planning phase | Require plan before implementation |
| Describe patterns abstractly | Show reference examples — agents copy, not interpret |
| Dump everything into AGENTS.md | Progressive disclosure, pointers to detailed docs |
| Use LLM as a linter | Use deterministic formatters and linters |
| Define no permission boundaries | Explicitly list allowed vs restricted operations |
| No feedback loop | Every review comment → rule or linter |
| Auto-enable token-costly hooks | Always get explicit consent with cost estimate |
| Write hooks without guidance messages | Every block must tell the agent what to do instead |
| Skip hook consent in bootstrap | Two-tier: recommended (free) batch, optional (costly) explicit |

---

## Onboarding a Repo: Quick Start

```
Day 1:  L1 — Write CLAUDE.md, add pre-commit hooks, self-review checklist
Week 1: L1 — Add reference examples, verify agent can build/test/lint
Week 2: L2 — Add architecture linters to CI, write ARCHITECTURE.md, configure Claude Code hooks
Week 3: L2 — Add boundary validation, continuation context
Month 2: L2 — Testing strategy, feedback loop operational
Month 3: L3 — Multi-agent, metrics, doc-gardener (if needed)
```

---

## References

### Primary Sources
1. [Harness engineering: leveraging Codex in an agent-first world (OpenAI)](https://openai.com/index/harness-engineering/)
2. [Harness Engineering: Complete Guide (NxCode)](https://www.nxcode.io/resources/news/harness-engineering-complete-guide-ai-agent-codex-2026)
3. [Evaluating AGENTS.md: Are Repository-Level Context Files Helpful? (arXiv 2602.11988v1)](https://arxiv.org/html/2602.11988v1)
4. [Writing a good CLAUDE.md (HumanLayer)](https://www.humanlayer.dev/blog/writing-a-good-claude-md)

### Tools
5. [dependency-cruiser](https://github.com/sverweij/dependency-cruiser) — TypeScript dependency validation
6. [eslint-plugin-boundaries](https://github.com/javierbrea/eslint-plugin-boundaries) — TypeScript architectural layers
7. [Ruff](https://github.com/astral-sh/ruff) — Python linter with auto-fix
8. [golangci-lint](https://golangci-lint.run/) — Go linter aggregator with depguard
9. [Mergify](https://docs.mergify.com/) — Merge queues and auto-rebase
10. [adr-toolkit](https://github.com/lordcraymen/adr-toolkit) — ADR management

### Patterns
11. [LoopAgent: Self-correcting AI agents (ADK)](https://medium.com/google-developer-experts/build-ai-agents-that-self-correct-until-its-right-adk-loopagent-f620bf351462)
12. [9 Parallel AI Agents for Code Review](https://hamy.xyz/blog/2026-02_code-reviews-claude-subagents)
13. [Claude Code Templates (davila7)](https://github.com/davila7/claude-code-templates)
14. [AGENTS.md Best Practices (Gist)](https://gist.github.com/0xfauzi/7c8f65572930a21efa62623557d83f6e)
15. [Claude Code Analytics API](https://platform.claude.com/docs/en/build-with-claude/claude-code-analytics-api)
16. [Self-Improving Coding Agents (Addy Osmani)](https://addyosmani.com/blog/self-improving-agents/)
