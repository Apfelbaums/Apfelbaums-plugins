# skill-stats

Track Claude Code usage by skill invocation with real-time LiteLLM pricing.

## Features

- **Skill tracking** — Counts every `/skill` invocation across all sessions
- **Nested attribution** — Shows which skills call other skills (tree view)
- **Real-time pricing** — Fetches current prices from LiteLLM (2000+ models)
- **Tiered pricing** — Applies 200k token threshold for Claude models
- **Token breakdown** — Input, output, cache read, cache create

## Usage

```bash
/skill-stats              # Full report for all time
/skill-stats today        # Today's usage only
/skill-stats --json       # Output as JSON for scripting
```

## Example Output

```
SKILL USAGE REPORT (ALL TIME)
══════════════════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────┬───────┬──────────┬──────────┬──────────┬──────────┐
│ Skill                                    │ Count │  Tokens  │   Cost   │ Avg Tok  │ Avg Cost │
├──────────────────────────────────────────┼───────┼──────────┼──────────┼──────────┼──────────┤
│ subagent-driven-development              │    25 │   168.9M │     $170 │     6.8M │    $6.78 │
│ ├── subagent-driven-development          │     1 │     4.2M │    $3.01 │     4.2M │    $3.01 │
│ └── finishing-a-development-branch       │     1 │     828K │    $0.46 │     828K │    $0.46 │
│ using-git-worktrees                      │    24 │   117.3M │    $88.3 │     4.9M │    $3.68 │
│ systematic-debugging                     │    25 │   123.3M │    $88.3 │     4.9M │    $3.53 │
│ writing-plans                            │    43 │    50.5M │    $54.4 │     1.2M │    $1.27 │
├──────────────────────────────────────────┼───────┼──────────┼──────────┼──────────┼──────────┤
│ TOTAL                                    │   405 │  1065.7M │     $814 │     2.6M │    $2.01 │
└──────────────────────────────────────────┴───────┴──────────┴──────────┴──────────┴──────────┘

Pricing: LiteLLM (real-time) | Tiered at 200k tokens | Nested skills shown as tree
```

## How It Works

1. Scans `~/.claude/projects/**/*.jsonl` for Skill tool calls
2. Tracks nested skill executions with stack-based attribution
3. Fetches pricing from [LiteLLM](https://github.com/BerriAI/litellm) (falls back to hardcoded prices offline)
4. Calculates costs using tiered pricing (tokens above 200k cost more)

## Pricing

Uses real-time pricing from LiteLLM with fallback:

| Model | Input | Output | Cache Read | Cache Create |
|-------|-------|--------|------------|--------------|
| Claude Sonnet | $3/1M | $15/1M | $0.30/1M | $3.75/1M |
| Claude Opus | $15/1M | $75/1M | $1.50/1M | $18.75/1M |
| Claude Haiku | $0.80/1M | $4/1M | $0.08/1M | $1/1M |

## Installation

```bash
claude plugin install skill-stats@apfelbaum-plugins
```

## Credits

- Pricing data from [LiteLLM](https://github.com/BerriAI/litellm)
- Pricing approach inspired by [ccusage](https://github.com/ryoppippi/ccusage)

## License

MIT
