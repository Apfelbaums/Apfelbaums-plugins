# Harness Engineering

Make repositories work as operating systems for AI agents. Based on OpenAI's Codex harness, arXiv research, and production experience.

## What is Harness Engineering?

Core principle: **enforce boundaries mechanically, allow autonomy locally**. The repository is an operating system for agents. You care about correctness and architecture — not stylistic preferences.

> OpenAI's Codex team: 1M+ LOC, zero lines written by humans, ~1,500 PRs in 5 months. The harness, not the prompt, is the primary lever for scale.

## Three Modes

### 1. Audit Mode

Evaluate your repository's agent-readiness across L1/L2/L3 maturity levels.

**Usage:**
```bash
/harness-engineering
# Select: Audit
```

**What it checks:**
- L1 (Basic Harness): CLAUDE.md, pre-commit hooks, test suite, self-review checklist
- L2 (Team Harness): Custom linters, architecture docs, continuation context
- L3 (Full Autonomy): Multi-agent coordination, metrics, doc-gardeners

**Output:** Detailed audit report with prioritized gaps and recommended next steps.

### 2. Apply Mode

Implement specific harness elements in your repository.

**Usage:**
```bash
/harness-engineering
# Select: Apply
# Choose what to add/fix
```

**Can apply:**
- CLAUDE.md (under 2000 tokens)
- Pre-commit hooks with secret scanning
- Architecture linters (TypeScript, Python, Go)
- ARCHITECTURE.md with domain map
- ADRs (Architecture Decision Records)
- Reference examples

### 3. Bootstrap L2 Mode

**Fully automated**. Scans your codebase and generates all missing L2 artifacts.

**Usage:**
```bash
/harness-engineering
# Select: Bootstrap L2
```

**Generates:**
- CLAUDE.md (auto-discovered commands, architecture, conventions)
- ARCHITECTURE.md (from actual code structure)
- .pre-commit-config.yaml (matching your stack)
- docs/examples/ (best patterns from your code)
- docs/adr/ (initial ADRs for key decisions)

All changes presented for approval before applying.

## Maturity Model

| Level | Name | What | When |
|-------|------|------|------|
| **L1** | Basic Harness | CLAUDE.md, pre-commit hooks, test suite | Day 1 — every repo |
| **L2** | Team Harness | Custom linters, architecture docs, testing strategy | Week 2 — active development |
| **L3** | Full Autonomy | Multi-agent, metrics, doc-gardeners | Month 2 — high-velocity repos |

## Key Features

- **MUST/MUST NOT language** — Agents follow constraints, not suggestions
- **Context minimalism** — CLAUDE.md stays under 2000 tokens
- **Linters with remediation** — Every error tells the agent HOW to fix it
- **Progressive disclosure** — Link to detailed docs, don't inline
- **Feedback loop** — Review comments → rules/linters

## Examples

### CLAUDE.md Template
```markdown
## Commands
- Install: `npm install`
- Test: `npm test`
- Lint: `npm run lint`

## Architecture
Layers (dependency flows top to bottom):
1. Types/Models — data shapes
2. Repository — database access
3. Services — business logic
4. API/Routes — HTTP handlers

## Conventions
- MUST use `{ data, error }` envelope for API responses
- MUST NOT exceed 500 lines per file
- MUST prefix env vars with `APP_`
```

### Custom Architecture Linter
```javascript
// .dependency-cruiser.cjs
forbidden: [{
  from: { path: '^src/models' },
  to: { path: '^src/routes' },
  comment: 'Models must not import from routes. Move shared types to src/types/'
}]
```

## References

The plugin includes a comprehensive guide at `references/harness-guide.md` covering:
- Foundational principles
- L1/L2/L3 checklists
- Stack-specific linter examples (TypeScript, Python, Go)
- Anti-patterns to avoid
- Multi-agent coordination patterns
- Metrics and instrumentation

## License

MIT
