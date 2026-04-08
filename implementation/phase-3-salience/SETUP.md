---
description: FadeMem salience scoring setup for ABMS Phase 3
tags: [setup, fademem, salience, scoring, phase-3]
audience: { human: 80, agent: 20 }
purpose: { low-agency-process: 60, reference: 40 }
---

# Phase 3: Salience Scoring

Phase 3 adds importance scoring to memory results so the most relevant corrections and memories surface within the token budget.

## Prerequisites

- Phase 1 and Phase 2 installed and working
- Python 3.9+

## Step 1: Install the scorer

```bash
cp implementation/phase-3-salience/fademem_scorer.py ~/.claude/rules-engine/
```

## Step 2: Update inject.sh

The Phase 2 inject script queries MemPalace and returns raw results. With the scorer, results are ranked by importance before injection:

```python
# Add to inject.sh (or call as a Python helper)
from fademem_scorer import score_and_rank

raw_results = mempalace_search(query, limit=10)
ranked = score_and_rank(raw_results, budget=3)
# Only the top 3 by importance are injected
```

## How Scoring Works

Each memory gets an importance score:

```
I(t) = 0.5 * relevance + 0.3 * frequency + 0.2 * recency
```

| Factor | What It Measures | Range |
|--------|-----------------|-------|
| relevance | Cosine similarity to current action context | 0–1 |
| frequency | `access_count / (1 + access_count)` — saturating | 0–1 |
| recency | `exp(-0.05 * days_since_last_access)` — 14-day half-life | 0–1 |

Corrections get a 1.5x boost.

## Classification

| Score | Level | Behavior |
|-------|-------|----------|
| >= 0.7 | High | Always surfaced when tags match |
| 0.3–0.7 | Medium | Surfaced if token budget allows |
| < 0.3 | Low | Only via semantic search, not tag matching |

## Tuning

The weights (ALPHA, BETA, GAMMA) and decay rate are in `fademem_scorer.py`. Adjust based on your experience:

- Increase ALPHA if irrelevant corrections keep surfacing (weight relevance more)
- Increase BETA if frequently-needed corrections aren't prioritized enough
- Increase GAMMA if stale corrections keep appearing
- Adjust DECAY_RATE to change the half-life (0.05 ≈ 14 days, 0.1 ≈ 7 days)
