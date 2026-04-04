# fact-check

Multi-agent fact verification for legal and financial documents.

## What it does

Extracts every factual claim from a document, verifies each against web sources using parallel agents, cross-checks critical findings, and produces:

1. **Fact-check report** with verification status for each claim
2. **Patched document** with inline source links, warnings for unverified claims, and corrections

## Usage

```bash
/fact-check <path-to-document>                # Full check (all 5 phases)
/fact-check <path-to-document> --quick        # Skip cross-check
/fact-check <path-to-document> --patch-only   # Just add source links
```

## Pipeline

| Phase | What | Parallel? |
|-------|------|-----------|
| **1. Extract** | Pull all verifiable claims from document sections | Yes (2-5 agents) |
| **2. Batch** | Group claims by topic for efficient search | No |
| **3. Verify** | Web search per batch | Yes (3-5 agents) |
| **4. Cross-Check** | Re-verify incorrect + critical claims with different queries | No |
| **5. Report + Patch** | Generate report and patched document | No |

## Claim Types

Supports 8 claim types with type-specific verification strategies:

| Type | Min Sources | Priority |
|------|-------------|----------|
| **number** | 2 | Highest |
| **law** | 1 official | Highest |
| **date** | 1 official | High |
| **event** | 2 | Medium |
| **company** | 1 registry | Medium |
| **quote** | 1 original | Medium |
| **process** | 2 | Lower |
| **comparison** | 2+ | Lower |

## Verdict Scale

| Verdict | Condition |
|---------|-----------|
| ✅ RELIABLE | >90% verified, 0% incorrect |
| ⚠️ NEEDS REVIEW | 80-90% verified, or >0% incorrect |
| 🔴 UNRELIABLE | <80% verified, or >5% incorrect |

## Quality Targets

- Verification rate: >80%
- Official source rate: >50%
- Incorrect claim rate: <5%
- Source freshness: >80% from last 2 years

## References

- [claim-types.md](references/claim-types.md) — Verification strategies per claim type
- [pipeline.md](references/pipeline.md) — Advanced pipeline details and edge cases
- [report-template.md](references/report-template.md) — Report output template
