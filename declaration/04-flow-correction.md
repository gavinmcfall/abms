---
description: Flow for correction lifecycle — from incident through filing, matching, decay, and promotion
tags: [flow, corrections, lifecycle, promotion, decay, fademem]
audience: { human: 60, agent: 40 }
purpose: { flow: 80, design: 20 }
---

# Flow: Correction Lifecycle

## Purpose

Track a correction from the moment a behavioral failure is identified through its useful life — being matched to future actions, decaying if irrelevant, or being promoted to a permanent rule if persistent.

## Actors

| Actor | Role |
|-------|------|
| **User** | Identifies behavioral failure, files or confirms correction |
| **Assistant** | The subject of the correction; may assist in filing |
| **Correction file** | Markdown file with frontmatter tags, stored in corrections/ |
| **inject.sh** | Matches corrections to future actions |
| **outcome.sh** | Bumps access counts when corrections are surfaced |
| **FadeMem scorer** | Calculates importance for retrieval ranking (Phase 3+) |
| **Promotion logic** | Detects recurring corrections and suggests promotion |

## Lifecycle Stages

```
┌──────────────────────────────────────────────────┐
│ STAGE 1: INCIDENT                                 │
│                                                    │
│ The assistant makes a behavioral error:            │
│   - Claims "done" without verifying                │
│   - Checks HTTP 200 but not response body          │
│   - Recommends a function that doesn't exist       │
│   - Misses mobile viewport on UI work              │
│                                                    │
│ The user notices and corrects the assistant.        │
└─────────────────────┬────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────┐
│ STAGE 2: FILING                                   │
│                                                    │
│ A correction file is created:                      │
│                                                    │
│   corrections/2026-04-08_shallow-api-check.md      │
│   ┌──────────────────────────────────────────┐    │
│   │ ---                                      │    │
│   │ tags: api, completion, shallow-verify     │    │
│   │ date: 2026-04-08                         │    │
│   │ severity: high                           │    │
│   │ access_count: 0                          │    │
│   │ last_accessed: null                      │    │
│   │ ---                                      │    │
│   │                                          │    │
│   │ Claimed API endpoint was working based   │    │
│   │ on 200 status code. Response body        │    │
│   │ contained UUIDs where localized names    │    │
│   │ should have been. Check response body    │    │
│   │ contents, not just status codes.         │    │
│   └──────────────────────────────────────────┘    │
│                                                    │
│ Filed by: user (manual), assistant (with confirm), │
│           or abms CLI tool                         │
└─────────────────────┬────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────┐
│ STAGE 3: DORMANT                                  │
│                                                    │
│ The correction sits in corrections/ waiting to     │
│ be matched. It has not yet been tested against     │
│ real actions.                                      │
│                                                    │
│ State: access_count=0, last_accessed=null          │
└─────────────────────┬────────────────────────────┘
                      ↓
┌──────────────────────────────────────────────────┐
│ STAGE 4: ACTIVE                                   │
│                                                    │
│ inject.sh matches the correction to an action:     │
│   - Tags match the current ruleset ("api")         │
│   - OR semantic search finds it relevant (Phase 2+)│
│                                                    │
│ The correction is injected into the assistant's     │
│ context pre-action.                                │
│                                                    │
│ outcome.sh bumps access_count and last_accessed.   │
│                                                    │
│ State: access_count increments with each match     │
└─────────────────────┬────────────────────────────┘
                      ↓
            ┌─────────┴─────────┐
            ↓                   ↓
┌───────────────────┐ ┌────────────────────────────┐
│ PATH A: DECAY     │ │ PATH B: PROMOTION          │
│                   │ │                            │
│ The correction    │ │ The correction fires       │
│ stops matching    │ │ repeatedly:                │
│ actions. No       │ │   access_count >= 5        │
│ access for 30+    │ │                            │
│ days.             │ │ System flags it:           │
│                   │ │ "This correction has fired │
│ FadeMem importance│ │  {N} times. Consider       │
│ score drops:      │ │  promoting to a permanent  │
│ - recency → 0    │ │  rule in contexts/{x}.md"  │
│ - frequency → low│ │                            │
│                   │ │ User reviews and promotes: │
│ The correction    │ │ - Content moves to         │
│ remains in        │ │   contexts/{ruleset}.md    │
│ corrections/ but  │ │ - Correction file archived │
│ is ranked below   │ │   or deleted               │
│ active ones in    │ │ - The behavioral rule is   │
│ search results.   │ │   now permanent            │
│                   │ │                            │
│ It is NOT deleted │ │ State: promoted            │
│ — it may become   │ │                            │
│ relevant again.   │ │                            │
│                   │ │                            │
│ State: dormant    │ │                            │
│ (low importance)  │ │                            │
└───────────────────┘ └────────────────────────────┘
```

## Correction File Format

```yaml
---
tags: [comma, separated, ruleset, tags]
date: YYYY-MM-DD
severity: low | medium | high | critical
access_count: 0
last_accessed: null
promoted_to: null
---

{Plain text description of the correction.}

{What went wrong, what should have happened, what to check.}

{Optional: verbatim quote from the incident for context.}
```

**Tags** map to rulesets defined in `engine.sh`. A correction tagged `api, completion` will match when the ruleset is `api` or when the action looks like a completion claim on API work.

**Severity** affects display priority (critical corrections always surface, low corrections may be trimmed if the token budget is tight).

**access_count** and **last_accessed** are updated automatically by outcome.sh. They drive FadeMem importance scoring.

**promoted_to** is set when the correction graduates to a permanent rule, recording which context file it was promoted into.

## Promotion Criteria

A correction is a candidate for promotion when:

1. `access_count >= 5` — it has been relevant to at least 5 distinct actions
2. The actions span at least 2 different sessions — not just repeated in one session
3. The correction was present AND the assistant still failed at least once — it addresses a persistent pattern, not a one-time mistake

Promotion is a user decision. The system suggests; the user acts. The suggestion appears as output from inject.sh:

```
⚠ RECURRING CORRECTION: "Check response body, not just status code"
  Fired 7 times across 4 sessions. Last failed despite being present.
  Consider promoting to contexts/api.md as a permanent rule.
```

## Decay Mechanics

**Phase 1 (no FadeMem):** Corrections are always included if their tags match. No decay. This means the corrections directory could grow unbounded — but in practice, manual filing keeps the volume low.

**Phase 3+ (FadeMem scoring):** Each correction gets an importance score:

```
I(t) = α · relevance_to_current_action
     + β · access_count / (1 + access_count)
     + γ · exp(-δ · days_since_last_accessed)
```

- High importance (I ≥ 0.7): always surface when tags match
- Medium importance (0.3 ≤ I < 0.7): surface if token budget allows
- Low importance (I < 0.3): only surface via semantic search (Phase 2+), not tag matching

Corrections never auto-delete. They lose retrieval priority, which is functionally equivalent to forgetting without the permanence of deletion.

## Failure Modes

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Correction never matches | Wasted filing effort; no behavioral impact | Review unmatched corrections quarterly; retag or delete |
| Correction matches too broadly | Irrelevant noise injected frequently | Narrow tags; add negative tags (e.g., `!infra` = never match infra) |
| Premature promotion | Permanent rule added for a temporary pattern | Require multi-session span before promotion; user confirms |
| Correction present but assistant still fails | The injection is not preventing the behavior | Escalate severity; consider whether this needs a hard block (hook) rather than an advisory rule |
| Too many corrections for one ruleset | Token budget exceeded; important ones may be trimmed | Severity-based prioritization; promote the most important ones to reduce correction count |

## The Feedback Signal

The critical insight: **corrections that keep being needed tell you something about the LLM's trained patterns.** A correction that fires 20 times across 10 sessions for the same behavior means the trained pattern is strong enough to override advisory rules. At that point, the correction should be escalated from advisory (injected rules) to enforcement (blocking hooks), following the pattern of the existing verification gate.

The lifecycle is:
1. Incident → correction (advisory)
2. Recurring correction → permanent rule (advisory, always present)
3. Persistent failure despite rule → blocking hook (enforcement)

Each escalation increases the system's ability to change behavior, at the cost of flexibility.
