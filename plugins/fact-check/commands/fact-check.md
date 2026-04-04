---
name: fact-check
description: Use when research documents contain factual claims that need verification — law references, tax rates, costs, dates, company info, regulatory status. Use before presenting findings to stakeholders. Use after compiling data from multiple AI research runs.
user-invocable: true
argument-hint: "[path-to-document]"
---

# Fact-Check — Multi-Agent Verification

Verify every factual claim in a document against web sources. Add citation links. Flag unverified claims. Produce a patched document with inline corrections.

## Core Principle

If a claim has no source URL, it's an assumption, not a fact.

## When to Use

- After completing legal/finance research
- Before presenting brainstorm results to partners
- When document has numbers, dates, law references, company info
- After compiling data from multiple AI research runs

Don't use for opinion/recommendation documents or internal projections.

## Pipeline Overview

| Phase | What | How | Parallel? |
|-------|------|-----|-----------|
| **1. Extract** | Pull all verifiable claims | 2-5 Agent sub-agents by section | Yes |
| **2. Batch** | Group claims by topic | Main agent | No |
| **3. Verify** | Web search per batch | 3-5 Agent sub-agents | Yes |
| **4. Cross-Check** | Re-verify incorrect + critical | 1 Agent | No |
| **5. Report + Patch** | Generate report, patch document | Main agent | No |

**Important:** Multi-agent parallelism works when YOU are the main agent (direct `/fact-check` invocation). If you're already running as a sub-agent, fall back to sequential single-agent execution — still follow all 5 phases, just do each step yourself instead of spawning agents.

## Phase 1: Extract Claims

Split the document into sections by headings. For each section, spawn an Agent sub-agent to extract claims.

**How to split:**

| Doc Size | Lines | Agents |
|----------|-------|--------|
| Short | <300 | 2 |
| Medium | 300-700 | 3 |
| Long | 700+ | 4-5 |

**Spawn agents like this — use the Agent tool with `run_in_background: true`:**

```
Agent(
  name: "extract-section-1",
  prompt: "Read lines 1-140 of [path] and extract ALL factual claims.
Output markdown table: | # | Claim (exact text) | Type | Line | Critical? |
Rules: extract numbers, dates, law refs, company names. SKIP opinions/recommendations.
Save to: [workspace]/extract-section-1.md",
  run_in_background: true
)
```

After all agents complete, merge outputs, remove duplicates, assign sequential IDs.

## Phase 2: Batch Claims

Group claims by topic for efficient web search. Done by main agent (you).

**Rules:**
- Max 8-12 claims per batch
- Group by jurisdiction + topic (e.g., "Seychelles VASP", "Panama tax", "Sanctions")
- Critical claims (numbers, laws) in smaller batches (max 5)

## Phase 3: Verify Claims

Spawn parallel Agent sub-agents, one per batch.

```
Agent(
  name: "verify-batch-1",
  prompt: "Verify these claims by searching the web (use WebSearch):
[claims list]
For EACH: Status (VERIFIED/UNVERIFIED/INCORRECT/PARTIALLY), Source URL, Source quote, Notes.
Rules: prefer official sources, 'no source' = UNVERIFIED not INCORRECT.
Save to: [workspace]/verify-batch-1.md",
  run_in_background: true
)
```

## Phase 4: Cross-Check

Re-verify ONLY: incorrect claims, unverified+critical, suspicious sources.

**Must use DIFFERENT search queries and find at least 1 different source.**

**Best practice:** Use web search tools with varied queries for cross-check. Try restricting to official domains when verifying regulatory/legal claims:

```
Search: "Panama registered agent annual fee 2025"
Restricted: site:oecd.org OR site:treasury.gov OR site:dgi.mef.gob.pa
```

## Phase 5: Report + Patch

### 5a. Report

Save to `[doc-dir]/fact-check-YYYY-MM-DD.md`. Use the template from [report-template.md](../references/report-template.md). Include:
- Summary table (total claims, verified/unverified/incorrect/partially counts and %)
- Verdict: RELIABLE (>90% verified, 0% incorrect) / NEEDS REVIEW / UNRELIABLE
- Tables for each status category with source URLs
- Source quality breakdown
- Recommendations

### 5b. Patched Document

Save backup, then create patched version in outputs (do NOT modify original):

```markdown
# Verified: add source link
Capital requirement: USD 100,000 ([FSA Seychelles](https://fsaseychelles.sc/vasp/fees))

# Unverified: add warning
Application takes 12-18 months ⚠️ *[not verified]*

# Incorrect: fix + note
Application fee: $70,000 ([AFSA](https://afsa.aifc.kz/fees)) ~~$50,000~~
```

## Claim Types

See [claim-types.md](../references/claim-types.md) for verification strategies per type:

| Type | Min Sources | Priority |
|------|-------------|----------|
| **number** | 2 | Highest — wrong costs = wrong decisions |
| **law** | 1 official | Highest — wrong legal status = illegal ops |
| **date** | 1 official | High — wrong dates = missed deadlines |
| **event** | 2 | Medium |
| **company** | 1 registry | Medium |
| **quote** | 1 original | Medium |
| **process** | 2 | Lower |
| **comparison** | 2+ (both sides) | Lower |

## Verification Statuses

| Status | Meaning | Action |
|--------|---------|--------|
| ✅ VERIFIED | Confirmed by source URL | Add source link |
| ⚠️ UNVERIFIED | No source found | Add warning marker |
| ❌ INCORRECT | Source contradicts claim | Fix + add correct source |
| 🔄 PARTIALLY | Partially correct | Add note + source |

## Execution Modes

```
/fact-check <path>                    # Full check (all 5 phases)
/fact-check <path> --quick            # Skip cross-check (phases 1-3 + 5)
/fact-check <path> --patch-only       # Just add source links to already-cited claims
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Not using Agent tool for parallelism | Spawn real Agent sub-agents for extraction and verification (when running as main agent) |
| Trusting AI search summaries without URL | Always get the actual source URL |
| Marking "no source found" as INCORRECT | It's UNVERIFIED — different thing |
| Using Wikipedia as primary source | Use Wikipedia to FIND official sources |
| Skipping cross-check for ❌ claims | Corrections MUST be verified — who fact-checks the fact-checker? |
| Verifying opinions ("we recommend...") | Only verify factual claims |
| Same search query for verify AND cross-check | Defeats the purpose — use different queries |

## Quality Targets

| Metric | Target |
|--------|--------|
| Verification rate | >80% |
| Official source rate | >50% |
| Incorrect rate | <5% |
| Source freshness | >80% from last 2 years |

## Language

- Report and patching: match the document's language
- Source quotes in original language (with translation if needed)
- Agent prompts can be in English (for better web search), but output matches document language

## Output

- **Report:** `[doc-dir]/fact-check-YYYY-MM-DD.md`
- **Patched doc:** Copy with inline links + ⚠️ warnings + ❌ corrections (in outputs dir)
- **Backup:** Original saved before patching (if patching original)
