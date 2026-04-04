# Fact-Check Pipeline — Advanced Details

This file contains additional details for edge cases. The main pipeline is in the command file.

## Smart Batching Examples

```
Batch 1: "Seychelles VASP Act 2024" → Claims #1, #3, #7, #12
Batch 2: "Kazakhstan AIFC licensing" → Claims #15, #18, #22, #25
Batch 3: "Sanctions precedents 2024" → Claims #30, #31, #32
```

## Cross-Check Rules

The cross-check agent must:
1. Use DIFFERENT search queries than Phase 3
2. Find at least 1 DIFFERENT source per claim
3. If cross-check disagrees with Phase 3, include both findings in report

## Final Review Checklist

Before generating the report, verify:

1. **Consistency** — no two verified claims contradict each other
2. **Source Quality** — all ✅ claims have real URLs (not 404), official sources >50%
3. **Gap Analysis** — no important sections with 0 verified claims
4. **Logic Check** — recommendations are based on verified (not unverified) claims
5. **Conflict Resolution** — for each conflict, note which source is more reliable/recent

## Red Flags — STOP and Investigate

- Claim has no source but marked ✅
- Source URL returns 404 or unrelated content
- Two verified claims contradict each other
- Critical recommendation based on unverified claims
- Agent marks ❌ INCORRECT but correction has no source URL
- Circular references (A cites B cites A)
