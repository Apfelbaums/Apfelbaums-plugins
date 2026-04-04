# Apfelbaums-Plugins

A collection of Claude Code plugins for LLM-first development workflows.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [harness-engineering](#harness-engineering) | Make repositories work as operating systems for AI agents |
| [project-documentation](#project-documentation) | Post-task documentation checklist for keeping docs current |
| [llm-friendliness-review](#llm-friendliness-review) | Audit your codebase for LLM-friendliness |
| [skill-stats](#skill-stats) | Track Claude Code usage by skill invocation with LiteLLM pricing |
| [fact-check](#fact-check) | Multi-agent fact verification for legal and financial documents |

---

## Installation

### 1. Add the marketplace

```bash
/plugin marketplace add Apfelbaums/claude-code-plugins
```

### 2. Install a plugin

```bash
/plugin install llm-friendliness-review@apfelbaum-plugins
```

---

## Plugins

### harness-engineering

Make repositories work as operating systems for AI agents. Based on OpenAI's Codex harness, arXiv research, and production experience.

**Usage:**

```bash
/harness-engineering
```

**Three Modes:**

1. **Audit** — Evaluate agent-readiness across L1/L2/L3 maturity levels
2. **Apply** — Implement specific harness elements (CLAUDE.md, linters, architecture docs)
3. **Bootstrap L2** — Fully automated setup of all missing L2 artifacts

**Maturity Levels:**

| Level | Name | What |
|-------|------|------|
| **L1** | Basic Harness | CLAUDE.md, pre-commit hooks, test suite |
| **L2** | Team Harness | Custom linters, architecture docs, testing strategy |
| **L3** | Full Autonomy | Multi-agent coordination, metrics, doc-gardeners |

**Key Features:**
- MUST/MUST NOT language for clear constraints
- Context minimalism (CLAUDE.md under 2000 tokens)
- Linters with remediation messages
- Architecture enforcement (TypeScript, Python, Go)
- Comprehensive guide at `references/harness-guide.md`

**Example Audit Output:**

```markdown
## Current Level: L1 (partial)

### Gaps (prioritized)

#### Critical (blocks agent effectiveness)
- Missing CLAUDE.md → Create with commands, architecture, conventions
- No pre-commit hooks → Add secret scanning, formatting

#### Important (improves quality)
- No architecture docs → Create ARCHITECTURE.md with domain map
- Missing reference examples → Add docs/examples/

### Recommended Next Steps
1. Create CLAUDE.md with build/test commands
2. Add pre-commit hooks with detect-private-key
3. Document architecture in ARCHITECTURE.md
```

---

### project-documentation

Post-task documentation checklist. Ensures docs stay current after code or infrastructure changes.

**Usage:**

```bash
/project-documentation
```

**How it Works:**

1. Auto-detects project type (codebase vs command center)
2. Presents yes/no checklist based on project type
3. Guides you to update only what changed

**Codebase Checklist:**
- Architecture changes → ARCHITECTURE.md, ADRs
- New patterns → docs/examples/
- Infrastructure → docs/, CLAUDE.md
- API changes → API docs
- Conventions → CLAUDE.md MUST/MUST NOT
- Cross-project dependencies

**Command Center Checklist:**
- Infrastructure → INFRASTRUCTURE.md
- Services → SERVICES.md
- Projects → PROJECTS.md
- Agents → AGENTS.md
- Workflows → WORKFLOWS.md

**Example:**

After adding a new API endpoint with rate limiting:
- ✅ Update ARCHITECTURE.md (new rate-limiting layer)
- ✅ Add docs/examples/rate-limited-endpoint.md
- ✅ Update API docs
- ✅ Add to CLAUDE.md: "MUST use rate limiter for all public endpoints"

---

### llm-friendliness-review

Comprehensive audit of your codebase for LLM-friendliness. Checks documentation, code clarity, hidden dependencies, architecture, and tests.

**Usage:**

```bash
/llm-friendliness-review
```

**What it checks:**

| Category | Checks |
|----------|--------|
| **Documentation** | CLAUDE.md exists and is comprehensive, entry points documented, README in subdirectories, changelog freshness, .env.example |
| **Code Clarity** | File sizes < 300 lines, no vague function names, no `any` types, exported types, nesting depth, abbreviations, JSDoc coverage |
| **Hidden Magic** | Singletons, direct process.env usage, global state, module-level mutable state |
| **Architecture** | Circular dependencies, file naming consistency, directory depth |
| **Tests** | Fixtures exist, test coverage, tests for main modules |
| **Git Hygiene** | Git hooks, commit message quality, conventional commits |

**Output:**

The plugin runs two phases:
1. **Automated checks** via `audit.sh` — mechanical grep/wc checks
2. **Semantic checks** — LLM analyzes code for deeper issues (stale comments, naming consistency, dead code, etc.)

Results are categorized as:
- **FAIL** — Critical issues to fix immediately
- **WARN** — Issues to fix soon
- **PASS** — All good

**Example output:**

```
═══════════════════════════════════════════════════════════════
  DOCUMENTATION
═══════════════════════════════════════════════════════════════
  ▶ Entry point (CLAUDE.md)
    ✓ CLAUDE.md exists (338 lines)
  ▶ Entry points documented
    ✓ Entry points documented (8 mentions)
  ...

═══════════════════════════════════════════════════════════════
  SUMMARY
═══════════════════════════════════════════════════════════════

  Passed:   15
  Warnings: 12
  Failed:   1

  ✗ LLM will struggle with this codebase — fix FAILs first
```

---

### skill-stats

Track token usage and costs by skill invocation across all Claude Code sessions. Uses real-time pricing from LiteLLM.

**Usage:**

```bash
/skill-stats
```

Interactive mode prompts for period selection:

```
Found 11,197 files (1.1GB)

Period (all, today, 7d, 30 days, 60...):
```

Supports flexible period input:
- `today` / `сегодня` — today only
- `7d` / `7 days` / `7` — last N days
- `all` / empty — all time

**How it Works:**

The plugin works by parsing the local `*.jsonl` log files that Claude Code uses to store session history, typically located in `~/.claude/projects/`. It streams the data to remain memory-efficient and uses a stack-based approach to accurately attribute token usage to the correct skill, including those that are called by other skills (nested skills).

**Features:**

| Category | Description |
|---|---|
| **Data Source** | Scans and processes all `*.jsonl` logs from `~/.claude/projects/` to capture a complete history of skill usage across all your projects. |
| **Real-time Pricing** | Fetches the latest model pricing data directly from the official LiteLLM GitHub repository, ensuring cost calculations are always up-to-date for over 2,000 models. |
| **Tiered Pricing Model** | Accurately calculates costs for models like Claude Sonnet 3.5 that use tiered pricing, applying different rates for tokens used above a certain threshold (e.g., 200,000 tokens). |
| **Nested Skill Tracking** | Uses a stack to correctly attribute token usage and costs to the parent skill, even when one skill calls another. The output displays this as a tree, showing which skills were invoked as part of a larger workflow. |
| **Cache Token Support** | Tracks and calculates costs for `cache_read_input_tokens` and `cache_creation_input_tokens` separately, providing a more accurate cost analysis for workflows that use caching. |
| **Efficient Processing** | Streams data directly from log files, allowing it to process gigabytes of history without high memory consumption. |
| **Flexible Reporting** | Generate reports for specific periods (`today`, `7d`, `30d`, etc.) and supports JSON output via the `--json` flag for integration with other tools. |

**Example output:**

The output table shows the total `Count` of invocations, `Tokens` used, `Cost`, and the average tokens and cost per run. Nested skills are shown in a tree structure under their parent.

```
SKILL USAGE REPORT (TODAY)
══════════════════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────┬───────┬──────────┬──────────┬──────────┬──────────┐
│ Skill                                    │ Count │  Tokens  │   Cost   │ Avg Tok  │ Avg Cost │
├──────────────────────────────────────────┼───────┼──────────┼──────────┼──────────┼──────────┤
│ railway                                  │     3 │    12.6M │    $6.99 │     4.2M │    $2.33 │
│ ├── daily                                │     1 │     1.3M │    $1.83 │     1.3M │    $1.83 │
│ └── superpowers:brainstorming            │     2 │     737K │    $0.48 │     369K │    $0.24 │
├──────────────────────────────────────────┼───────┼──────────┼──────────┼──────────┼──────────┤
│ TOTAL                                    │     6 │    14.6M │    $9.30 │     2.4M │    $1.55 │
└──────────────────────────────────────────┴───────┴──────────┴──────────┴──────────┴──────────┘
```

---

### fact-check

Multi-agent fact verification for legal and financial documents. Extracts claims, verifies against web sources, cross-checks critical findings, and produces patched documents with citations.

**Usage:**

```bash
/fact-check <path-to-document>
```

**Pipeline (5 phases):**

1. **Extract** — Pull all verifiable claims using parallel agents (2-5 by document size)
2. **Batch** — Group claims by topic for efficient search
3. **Verify** — Web search per batch using parallel agents (3-5)
4. **Cross-Check** — Re-verify incorrect + critical claims with different queries
5. **Report + Patch** — Generate verification report and patched document with inline citations

**Supports 8 claim types:** law, number, date, event, company, quote, process, comparison — each with type-specific verification strategies, minimum source requirements, and red flags.

**Verdicts:**
- ✅ RELIABLE — >90% verified, 0% incorrect
- ⚠️ NEEDS REVIEW — 80-90% verified, or >0% incorrect
- 🔴 UNRELIABLE — <80% verified, or >5% incorrect

**Modes:**
- Full check (all 5 phases)
- `--quick` — skip cross-check
- `--patch-only` — just add source links to existing citations

---

## Local Development

To test plugins locally:

```bash
# Clone the repo
git clone https://github.com/Apfelbaums/claude-code-plugins.git

# Add as local marketplace
/plugin marketplace add ./claude-code-plugins

# Install plugin
/plugin install llm-friendliness-review@apfelbaum-plugins

# Test it
/llm-friendliness-review
```

---

## Contributing

Contributions welcome! To add a new plugin:

1. Create a directory in `plugins/your-plugin-name/`
2. Add `.claude-plugin/plugin.json` with metadata
3. Add your commands in `commands/`
4. Update `marketplace.json` with your plugin entry
5. Submit a PR

---

## License

MIT
