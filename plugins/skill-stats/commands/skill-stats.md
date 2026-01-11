---
description: "Track Claude Code usage by skill invocation with LiteLLM pricing"
---

# Skill Stats

Track token usage and costs by skill invocation across all Claude Code sessions.

## Usage

```bash
/skill-stats              # Full report for all time
/skill-stats today        # Today's usage only
/skill-stats --json       # Output as JSON
```

## Implementation

Run this TypeScript script using `npx tsx`:

```typescript
import * as fs from 'fs';
import { createReadStream } from 'fs';
import * as path from 'path';
import * as readline from 'readline';

const CLAUDE_DIR = process.env.HOME + '/.claude/projects';
const LITELLM_URL = 'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json';
const TIERED_THRESHOLD = 200_000;

interface LiteLLMPricing {
  input_cost_per_token?: number;
  output_cost_per_token?: number;
  cache_creation_input_token_cost?: number;
  cache_read_input_token_cost?: number;
  input_cost_per_token_above_200k_tokens?: number;
  output_cost_per_token_above_200k_tokens?: number;
  cache_creation_input_token_cost_above_200k_tokens?: number;
  cache_read_input_token_cost_above_200k_tokens?: number;
}

const FALLBACK_PRICING: Record<string, LiteLLMPricing> = {
  'claude-sonnet-4-20250514': {
    input_cost_per_token: 3e-6, output_cost_per_token: 15e-6,
    cache_read_input_token_cost: 0.30e-6, cache_creation_input_token_cost: 3.75e-6
  },
  'claude-3-5-sonnet-20241022': {
    input_cost_per_token: 3e-6, output_cost_per_token: 15e-6,
    cache_read_input_token_cost: 0.30e-6, cache_creation_input_token_cost: 3.75e-6
  },
  'claude-opus-4-5-20251101': {
    input_cost_per_token: 15e-6, output_cost_per_token: 75e-6,
    cache_read_input_token_cost: 1.50e-6, cache_creation_input_token_cost: 18.75e-6
  },
  'claude-3-5-haiku-20241022': {
    input_cost_per_token: 0.80e-6, output_cost_per_token: 4e-6,
    cache_read_input_token_cost: 0.08e-6, cache_creation_input_token_cost: 1e-6
  }
};

let pricingCache: Map<string, LiteLLMPricing> | null = null;

async function fetchPricing(): Promise<Map<string, LiteLLMPricing>> {
  if (pricingCache) return pricingCache;
  try {
    const response = await fetch(LITELLM_URL);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json() as Record<string, unknown>;
    pricingCache = new Map();
    for (const [model, pricing] of Object.entries(data)) {
      if (typeof pricing === 'object' && pricing !== null) {
        pricingCache.set(model, pricing as LiteLLMPricing);
      }
    }
    return pricingCache;
  } catch (e) {
    pricingCache = new Map(Object.entries(FALLBACK_PRICING));
    return pricingCache;
  }
}

const PROVIDER_PREFIXES = ['anthropic/', 'claude-3-5-', 'claude-3-', 'claude-'];

function findModelPricing(pricing: Map<string, LiteLLMPricing>, model: string): LiteLLMPricing | null {
  if (pricing.has(model)) return pricing.get(model)!;
  for (const prefix of PROVIDER_PREFIXES) {
    const withPrefix = `${prefix}${model}`;
    if (pricing.has(withPrefix)) return pricing.get(withPrefix)!;
  }
  const lower = model.toLowerCase();
  for (const [key, value] of pricing) {
    const comparison = key.toLowerCase();
    if (comparison.includes(lower) || lower.includes(comparison)) return value;
  }
  return null;
}

function calculateTieredCost(tokens: number | undefined, basePrice: number | undefined, tieredPrice: number | undefined): number {
  if (!tokens || tokens <= 0) return 0;
  if (tokens > TIERED_THRESHOLD && tieredPrice != null) {
    const belowThreshold = Math.min(tokens, TIERED_THRESHOLD);
    const aboveThreshold = tokens - TIERED_THRESHOLD;
    return (basePrice ?? 0) * belowThreshold + tieredPrice * aboveThreshold;
  }
  return (basePrice ?? 0) * tokens;
}

function calculateCost(tokens: TokenBreakdown, pricing: LiteLLMPricing): number {
  return (
    calculateTieredCost(tokens.input, pricing.input_cost_per_token, pricing.input_cost_per_token_above_200k_tokens) +
    calculateTieredCost(tokens.output, pricing.output_cost_per_token, pricing.output_cost_per_token_above_200k_tokens) +
    calculateTieredCost(tokens.cacheRead, pricing.cache_read_input_token_cost, pricing.cache_read_input_token_cost_above_200k_tokens) +
    calculateTieredCost(tokens.cacheCreate, pricing.cache_creation_input_token_cost, pricing.cache_creation_input_token_cost_above_200k_tokens)
  );
}

interface TokenBreakdown { input: number; output: number; cacheRead: number; cacheCreate: number; }
interface SkillExecution { skill: string; tokens: TokenBreakdown; model: string; nestedExecutions: SkillExecution[]; timestamp: string; }
interface ActiveSkill { skill: string; tokens: TokenBreakdown; model: string; nestedExecutions: SkillExecution[]; timestamp: string; }
interface ScanResult { fileCount: number; totalBytes: number; }

function formatBytes(bytes: number): string {
  if (bytes >= 1_000_000_000) return (bytes / 1_000_000_000).toFixed(1) + 'GB';
  if (bytes >= 1_000_000) return (bytes / 1_000_000).toFixed(1) + 'MB';
  if (bytes >= 1_000) return (bytes / 1_000).toFixed(0) + 'KB';
  return bytes + 'B';
}

function scanDataVolume(): ScanResult {
  let fileCount = 0, totalBytes = 0;
  if (!fs.existsSync(CLAUDE_DIR)) return { fileCount: 0, totalBytes: 0 };

  for (const project of fs.readdirSync(CLAUDE_DIR)) {
    const projectPath = path.join(CLAUDE_DIR, project);
    if (!fs.statSync(projectPath).isDirectory()) continue;
    for (const file of fs.readdirSync(projectPath).filter((f: string) => f.endsWith('.jsonl'))) {
      const stat = fs.statSync(path.join(projectPath, file));
      fileCount++;
      totalBytes += stat.size;
    }
  }
  return { fileCount, totalBytes };
}

async function promptPeriod(scan: ScanResult): Promise<string> {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  console.log(`\nFound ${scan.fileCount.toLocaleString()} files (${formatBytes(scan.totalBytes)})\n`);

  return new Promise((resolve) => {
    rl.question('Period (all, today, 7d, 30 days, 60...): ', (answer) => {
      rl.close();
      resolve(answer.trim().toLowerCase() || 'all');
    });
  });
}

function parsePeriod(input: string): (ts: string) => boolean {
  const now = new Date();
  const today = now.toISOString().split('T')[0];

  if (/^(today|сегодня)$/i.test(input)) {
    return (ts) => ts.startsWith(today);
  }

  const daysMatch = input.match(/^(\d+)\s*(d|days?|дн|дней|дня)?$/i);
  if (daysMatch) {
    const days = parseInt(daysMatch[1], 10);
    const cutoff = new Date(now.getTime() - days * 86400000).toISOString();
    return (ts) => ts >= cutoff;
  }

  return () => true;
}

function isRealUserMessage(entry: any): boolean {
  if (entry.type !== 'user') return false;
  const content = entry.message?.content;
  if (!content) return false;
  if (typeof content === 'string') {
    if (content.includes('Base directory for this skill')) return false;
    if (content.includes('<command-name>')) return false;
    return content.length > 0;
  }
  if (Array.isArray(content) && content.length > 0) {
    const first = content[0];
    if (first.tool_use_id) return false;
    if (first.type === 'tool_result') return false;
    if (first.type === 'text' && first.text) {
      if (first.text.includes('Base directory for this skill')) return false;
      if (first.text.includes('<command-name>')) return false;
      if (first.text.includes('ARGUMENTS:')) return false;
      return true;
    }
  }
  return false;
}

function getTokens(entry: any): { tokens: TokenBreakdown; model: string } {
  const usage = entry.message?.usage;
  if (!usage) return { tokens: { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 }, model: '' };
  return {
    tokens: {
      input: usage.input_tokens || 0,
      output: usage.output_tokens || 0,
      cacheRead: usage.cache_read_input_tokens || 0,
      cacheCreate: usage.cache_creation_input_tokens || 0
    },
    model: entry.message?.model || ''
  };
}

function addTokens(a: TokenBreakdown, b: TokenBreakdown): TokenBreakdown {
  return { input: a.input + b.input, output: a.output + b.output, cacheRead: a.cacheRead + b.cacheRead, cacheCreate: a.cacheCreate + b.cacheCreate };
}

function totalTokens(t: TokenBreakdown): number {
  return t.input + t.output + t.cacheRead + t.cacheCreate;
}

const sumNestedCache = new WeakMap<SkillExecution, TokenBreakdown>();

function sumNested(exec: SkillExecution): TokenBreakdown {
  const cached = sumNestedCache.get(exec);
  if (cached) return cached;

  let sum: TokenBreakdown = { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 };
  for (const nested of exec.nestedExecutions) {
    sum = addTokens(sum, nested.tokens);
    sum = addTokens(sum, sumNested(nested));
  }

  sumNestedCache.set(exec, sum);
  return sum;
}

class TimestampBuffer {
  private buffer: any[] = [];
  private readonly maxSize = 200;

  push(entry: any): any | null {
    this.buffer.push(entry);
    this.buffer.sort((a, b) => (a.timestamp || '').localeCompare(b.timestamp || ''));
    if (this.buffer.length > this.maxSize) return this.buffer.shift();
    return null;
  }

  flush(): any[] {
    const result = this.buffer;
    this.buffer = [];
    return result;
  }
}

async function* streamFileEntries(filePath: string, filterFn: (ts: string) => boolean): AsyncGenerator<any> {
  const fileStream = createReadStream(filePath, { encoding: 'utf-8' });
  const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });
  const buffer = new TimestampBuffer();

  for await (const line of rl) {
    if (!line.trim()) continue;
    let entry: any;
    try { entry = JSON.parse(line); } catch { continue; }

    if (!filterFn(entry.timestamp || '')) continue;

    const stable = buffer.push(entry);
    if (stable) yield stable;
  }

  for (const entry of buffer.flush()) yield entry;
}

async function findTopLevelExecutions(filterFn: (ts: string) => boolean): Promise<SkillExecution[]> {
  const topLevel: SkillExecution[] = [];

  if (!fs.existsSync(CLAUDE_DIR)) return topLevel;
  const projects = fs.readdirSync(CLAUDE_DIR);

  for (const project of projects) {
    const projectPath = path.join(CLAUDE_DIR, project);
    if (!fs.statSync(projectPath).isDirectory()) continue;
    const files = fs.readdirSync(projectPath).filter((f: string) => f.endsWith('.jsonl'));

    for (const file of files) {
      const filePath = path.join(projectPath, file);
      const stack: ActiveSkill[] = [];

      for await (const entry of streamFileEntries(filePath, filterFn)) {
        const { tokens, model } = getTokens(entry);

        if (stack.length > 0 && totalTokens(tokens) > 0) {
          stack[stack.length - 1].tokens = addTokens(stack[stack.length - 1].tokens, tokens);
          if (model && !stack[stack.length - 1].model) stack[stack.length - 1].model = model;
        }

        const message = entry.message;
        if (message?.content && Array.isArray(message.content)) {
          for (const block of message.content) {
            if (block.type === 'tool_use' && block.name === 'Skill' && block.input?.skill) {
              stack.push({
                skill: block.input.skill,
                tokens: { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 },
                model: '',
                nestedExecutions: [],
                timestamp: entry.timestamp || ''
              });
            }
          }
        }

        if (isRealUserMessage(entry)) {
          while (stack.length > 0) {
            const active = stack.pop()!;
            const completed: SkillExecution = { skill: active.skill, tokens: active.tokens, model: active.model, nestedExecutions: active.nestedExecutions, timestamp: active.timestamp };
            if (stack.length > 0) stack[stack.length - 1].nestedExecutions.push(completed);
            else topLevel.push(completed);
          }
        }
      }

      while (stack.length > 0) {
        const active = stack.pop()!;
        const completed: SkillExecution = { skill: active.skill, tokens: active.tokens, model: active.model, nestedExecutions: active.nestedExecutions, timestamp: active.timestamp };
        if (stack.length > 0) stack[stack.length - 1].nestedExecutions.push(completed);
        else topLevel.push(completed);
      }
    }
  }
  return topLevel;
}

function formatTokens(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(0) + 'K';
  return n.toString();
}

function formatCost(n: number): string {
  if (n >= 100) return '$' + n.toFixed(0);
  if (n >= 10) return '$' + n.toFixed(1);
  return '$' + n.toFixed(2);
}

interface SkillStats { count: number; tokens: TokenBreakdown; cost: number; nestedBySkill: Map<string, SkillStats>; }

async function aggregateStats(executions: SkillExecution[], pricing: Map<string, LiteLLMPricing>): Promise<Map<string, SkillStats>> {
  const stats = new Map<string, SkillStats>();

  function getCost(exec: SkillExecution): number {
    const p = findModelPricing(pricing, exec.model);
    if (!p) return 0;
    const allTokens = addTokens(exec.tokens, sumNested(exec));
    return calculateCost(allTokens, p);
  }

  function process(exec: SkillExecution, isTopLevel: boolean, parentStats?: SkillStats) {
    const totalTok = addTokens(exec.tokens, sumNested(exec));
    const cost = getCost(exec);

    if (isTopLevel) {
      const s = stats.get(exec.skill) || { count: 0, tokens: { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 }, cost: 0, nestedBySkill: new Map() };
      s.count++;
      s.tokens = addTokens(s.tokens, totalTok);
      s.cost += cost;

      for (const ne of exec.nestedExecutions) {
        const nTok = addTokens(ne.tokens, sumNested(ne));
        const nCost = getCost(ne);
        const ns = s.nestedBySkill.get(ne.skill) || { count: 0, tokens: { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 }, cost: 0, nestedBySkill: new Map() };
        ns.count++;
        ns.tokens = addTokens(ns.tokens, nTok);
        ns.cost += nCost;
        s.nestedBySkill.set(ne.skill, ns);
        process(ne, false, s);
      }
      stats.set(exec.skill, s);
    } else if (parentStats) {
      for (const ne of exec.nestedExecutions) {
        const nTok = addTokens(ne.tokens, sumNested(ne));
        const nCost = getCost(ne);
        const ns = parentStats.nestedBySkill.get(ne.skill) || { count: 0, tokens: { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 }, cost: 0, nestedBySkill: new Map() };
        ns.count++;
        ns.tokens = addTokens(ns.tokens, nTok);
        ns.cost += nCost;
        parentStats.nestedBySkill.set(ne.skill, ns);
        process(ne, false, parentStats);
      }
    }
  }

  for (const exec of executions) process(exec, true);
  return stats;
}

async function main() {
  const args = process.argv.slice(2);
  const jsonMode = args.includes('--json');

  // Interactive mode: scan and prompt for period
  const scan = scanDataVolume();
  const periodInput = await promptPeriod(scan);
  const filterFn = parsePeriod(periodInput);

  const pricing = await fetchPricing();
  const executions = await findTopLevelExecutions(filterFn);
  const stats = await aggregateStats(executions, pricing);
  const sorted = [...stats.entries()].sort((a, b) => b[1].cost - a[1].cost);

  let grandTokens: TokenBreakdown = { input: 0, output: 0, cacheRead: 0, cacheCreate: 0 };
  let grandCost = 0;
  let grandCount = 0;

  for (const [_, s] of sorted) {
    grandTokens = addTokens(grandTokens, s.tokens);
    grandCost += s.cost;
    grandCount += s.count;
  }

  if (jsonMode) {
    const output = {
      period: periodInput || 'all',
      total: { count: grandCount, tokens: totalTokens(grandTokens), cost: grandCost },
      skills: sorted.map(([skill, s]) => ({
        skill, count: s.count, tokens: totalTokens(s.tokens), cost: s.cost, avgCost: s.cost / s.count,
        nested: [...s.nestedBySkill.entries()].map(([n, ns]) => ({ skill: n, count: ns.count, tokens: totalTokens(ns.tokens), cost: ns.cost }))
      }))
    };
    console.log(JSON.stringify(output, null, 2));
    return;
  }

  const periodLabel = (periodInput || 'all').toUpperCase();
  console.log('');
  console.log(`SKILL USAGE REPORT (${periodLabel})`);
  console.log('═'.repeat(90));
  console.log('');
  console.log('┌──────────────────────────────────────────┬───────┬──────────┬──────────┬──────────┬──────────┐');
  console.log('│ Skill                                    │ Count │  Tokens  │   Cost   │ Avg Tok  │ Avg Cost │');
  console.log('├──────────────────────────────────────────┼───────┼──────────┼──────────┼──────────┼──────────┤');

  for (const [skill, s] of sorted) {
    const name = skill.length > 38 ? skill.substring(0, 35) + '...' : skill;
    const avgTok = totalTokens(s.tokens) / s.count;
    const avgCost = s.cost / s.count;

    console.log(
      '│ ' + name.padEnd(40) + ' │' +
      String(s.count).padStart(6) + ' │' +
      formatTokens(totalTokens(s.tokens)).padStart(9) + ' │' +
      formatCost(s.cost).padStart(9) + ' │' +
      formatTokens(avgTok).padStart(9) + ' │' +
      formatCost(avgCost).padStart(9) + ' │'
    );

    const nestedArr = [...s.nestedBySkill.entries()].sort((a, b) => b[1].cost - a[1].cost);
    for (let i = 0; i < Math.min(nestedArr.length, 4); i++) {
      const [nSkill, ns] = nestedArr[i];
      const isLast = i === Math.min(nestedArr.length, 4) - 1 && nestedArr.length <= 4;
      const prefix = isLast ? '└── ' : '├── ';
      const nName = nSkill.length > 34 ? nSkill.substring(0, 31) + '...' : nSkill;
      const nAvgTok = totalTokens(ns.tokens) / ns.count;
      const nAvgCost = ns.cost / ns.count;

      console.log(
        '│ ' + (prefix + nName).padEnd(40) + ' │' +
        String(ns.count).padStart(6) + ' │' +
        formatTokens(totalTokens(ns.tokens)).padStart(9) + ' │' +
        formatCost(ns.cost).padStart(9) + ' │' +
        formatTokens(nAvgTok).padStart(9) + ' │' +
        formatCost(nAvgCost).padStart(9) + ' │'
      );
    }
    if (nestedArr.length > 4) {
      const rest = nestedArr.slice(4);
      const restCost = rest.reduce((sum, [_, x]) => sum + x.cost, 0);
      const restTok = rest.reduce((sum, [_, x]) => sum + totalTokens(x.tokens), 0);
      console.log(
        '│ ' + ('└── (+' + rest.length + ' more)').padEnd(40) + ' │      │' +
        formatTokens(restTok).padStart(9) + ' │' +
        formatCost(restCost).padStart(9) + ' │          │          │'
      );
    }
  }

  const grandAvgTok = grandCount > 0 ? totalTokens(grandTokens) / grandCount : 0;
  const grandAvgCost = grandCount > 0 ? grandCost / grandCount : 0;

  console.log('├──────────────────────────────────────────┼───────┼──────────┼──────────┼──────────┼──────────┤');
  console.log(
    '│ ' + 'TOTAL'.padEnd(40) + ' │' +
    String(grandCount).padStart(6) + ' │' +
    formatTokens(totalTokens(grandTokens)).padStart(9) + ' │' +
    formatCost(grandCost).padStart(9) + ' │' +
    formatTokens(grandAvgTok).padStart(9) + ' │' +
    formatCost(grandAvgCost).padStart(9) + ' │'
  );
  console.log('└──────────────────────────────────────────┴───────┴──────────┴──────────┴──────────┴──────────┘');
  console.log('');
  console.log('Pricing: LiteLLM (real-time) | Tiered at 200k tokens | Nested skills shown as tree');
  console.log('');
}

main().catch(console.error);
```

## Steps

1. Parse arguments (`today`, `--json`)
2. Fetch pricing from LiteLLM (with fallback)
3. Scan `~/.claude/projects/**/*.jsonl` for Skill tool calls
4. Track nested skill executions with stack-based attribution
5. Calculate costs using tiered pricing
6. Output table or JSON

## Notes

- Pricing fetched from LiteLLM in real-time (2000+ models)
- Fallback to hardcoded pricing when offline
- Tiered pricing applies above 200k tokens for Claude models
- Nested skills shown as tree structure under parent
