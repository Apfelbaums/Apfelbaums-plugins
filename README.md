# Apfelbaums-Plugins

A collection of Claude Code plugins for LLM-first development workflows.

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [llm-friendliness-review](#llm-friendliness-review) | Audit your codebase for LLM-friendliness |

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
