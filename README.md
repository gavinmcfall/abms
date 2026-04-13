# ABMS — Adaptive Behavioral Memory System

A prosthetic limbic system for AI coding assistants. All four phases deployed. Enforcement integrated via [dcg](https://github.com/Dicklesworthstone/destructive_command_guard).

## The Problem

Large language models have no limbic system. They have no mechanism that decides what matters, no emotional tagging that determines what gets encoded deeply, no subconscious process that fires before a repeated mistake. Every session starts from the same weights. Every correction evaporates when the context window resets.

Memory products solve recall — finding stored information later. Multiple systems achieve 95%+ on standard benchmarks. But recall is not behavioral change. You can store "always verify before claiming done" in a dozen places and the LLM will still claim things are done without verifying. The instruction sits in context; the trained pattern wins.

In humans, the limbic system bridges this gap. It tags experiences with emotional weight, consolidates memories during sleep, and fires pre-conscious avoidance responses to situations that previously caused pain. A human who gets burned checks the stove before touching it — not because they consciously recall the rule, but because their nervous system changed.

ABMS is the software equivalent: a system that stores experiences verbatim, determines what matters through usage patterns, surfaces relevant knowledge at the moment of action (not at session start where it degrades), tracks what works and what doesn't, and escalates corrections that keep recurring from advisory to enforced.

## The Components

Five integrated layers in the PreToolUse hook chain:

```
Action about to fire
        ↓
┌───────────────────────────────────────────────────────────┐
│ 1. dcg                — 49+ security packs, hard enforce   │
│ 2. destructive-gate   — custom script flags (--wipe etc)   │
│ 3. git-safety         — git-specific advisory              │
│ 4. verify-gate        — commit requires passing tests      │
│ 5. rules-engine       — ABMS advisory: rules + corrections │
│                         + scored memory results            │
└───────────────────────────────────────────────────────────┘
        ↓
Action proceeds (with relevant knowledge in recency zone)
```

The ABMS rules engine provides four capabilities:

**Verbatim storage with spatial indexing** — Every conversation stored in ChromaDB, organized by project/person/topic. Semantic search retrieves relevant memories without requiring exact queries. Based on [MemPalace](https://github.com/milla-jovovich/mempalace).

**Salience-weighted forgetting** — Memories accessed frequently and recently stay strong; memories that stop being relevant decay. Based on [FadeMem](https://arxiv.org/abs/2601.18642)'s Ebbinghaus-inspired formula: `I(t) = 0.5·relevance + 0.3·frequency + 0.2·recency`. Corrections get a 1.5x salience boost.

**Point-of-action injection** — Rules and corrections surface in the recency zone of the context window (where attention is strongest) right before the AI acts. Not at session start where they degrade through a long conversation.

**Correction lifecycle** — When the AI fails, the incident is captured as a tagged correction file. Recurring corrections escalate from advisory (injected into context) to permanent (moved to static rulesets) to enforcement (blocked by hook). A weekly cron reviews correction health.

## The Documents

This is structured as an outcome-focused declaration chain — evidence through outcomes to architecture:

| Document | What It Establishes |
|----------|-------------------|
| [Findings](declaration/00-findings.md) | What is true — existing infrastructure, research evidence, gaps |
| [North Star](declaration/01-north-star.md) | What should be true — testable outcome declarations |
| [Flow: Injection](declaration/02-flow-injection.md) | How knowledge reaches the AI at the moment of action |
| [Flow: Outcomes](declaration/03-flow-outcomes.md) | How results are captured for future learning |
| [Flow: Correction Lifecycle](declaration/04-flow-correction.md) | How corrections are filed, matched, decayed, or promoted |
| [Design](declaration/05-design.md) | Architecture that makes all flows real |

Getting started:
- **[Setup Guide](SETUP-GUIDE.md)** — Clone, install, and have it running in ~30 minutes
- **[Conversation](CONVERSATION.md)** — The dialogue that led to this design (human + AI back-and-forth)

Implementation:
- [Rules Engine](implementation/rules-engine/) — Switch router, injection hook, outcome tracking, 9 context rulesets
- [Hooks](implementation/hooks/) — Verification gate, git safety, session journal, worklog, edit tracking, destructive gate
- [DCG Integration](implementation/hooks/DCG-INTEGRATION.md) — How dcg and ABMS complement each other
- [Protocols](implementation/protocols/) — Session journal, worklog, verification gate, auto-memory
- [Phase 2: Memory](implementation/phase-2-memory/) — MemPalace setup
- [Phase 3: Salience](implementation/phase-3-salience/) — FadeMem scorer
- [Phase 4: Self-Improving](implementation/phase-4-self-improving/) — Promotion, escalation, lifecycle review

Reference:
- [Existing Systems](reference/existing-systems.md) — Claude Code infrastructure ABMS integrates with
- [Research Sources](reference/research-sources.md) — Papers, products, benchmarks cited

## Phases

| Phase | What | Status |
|-------|------|--------|
| **1: Rules Engine** | Switch router, injection hook, outcome tracking, correction files | ✓ Deployed |
| **2: Memory** | Verbatim storage, semantic search, knowledge graph, auto-save hooks | ✓ Deployed |
| **3: Salience** | Importance scoring, usage-weighted decay, memory ranking | ✓ Deployed |
| **4: Self-Improving** | Promotion logic, failure pattern detection, enforcement escalation | ✓ Deployed |
| **Enforcement** | dcg integration for 49+ pack destructive command blocking | ✓ Deployed |

Phase 1 is zero-dependency (bash + markdown) and delivers value immediately. Each subsequent phase adds capability without replacing previous phases.

## Proven In Production

**April 12, 2026 — Staging data destruction incident.** A Claude session ran `load_staging.py --full-wipe` against staging with live user data. Three ABMS corrections relevant to this pattern had already fired **527 times combined** in preceding days. The infrastructure was working perfectly — the rules were present, surfaced, scored. But the AI trusted a docstring ("User/BA data is preserved") without reading the implementation, and ran the destructive op anyway.

This was the failure mode predicted in the north-star document: advisory corrections can shift the odds, but *can't guarantee* behavioral change against strong trained patterns. For high-stakes operations, advisory isn't enough.

The response was the full escalation ladder walking:
1. ✓ Incident filed as correction: `2026-04-12_trusted-docstring-destroyed-data.md`
2. ✓ Hook escalation: integrated [dcg](https://github.com/Dicklesworthstone/destructive_command_guard) + custom-flag `destructive-gate.sh` to physically block destructive commands
3. ✓ RFC updated with the incident and the enforcement response

The escalation ladder isn't hypothetical. It was tested in production on day three.

## Research Foundation

Draws from current work in AI memory systems, biologically-inspired forgetting, and empirically documented failure modes of LLM instruction following. See [research sources](reference/research-sources.md) for the full bibliography.

Key influences:
- **[MemPalace](https://github.com/milla-jovovich/mempalace)** — Verbatim storage + spatial indexing (96.6% LongMemEval recall)
- **[FadeMem](https://arxiv.org/abs/2601.18642)** — Ebbinghaus-inspired adaptive decay
- **[Control Illusion](https://arxiv.org/html/2502.15851v1)** — 39% degradation of instruction following in multi-turn conversations
- **[HEMA](https://arxiv.org/abs/2504.16754)** — Hippocampal dual-memory architecture
- **[dcg](https://github.com/Dicklesworthstone/destructive_command_guard)** — Production enforcement layer for destructive commands
- **[ICLR 2026 MemAgents Workshop](https://sites.google.com/view/memagent-iclr26/)** — The research community's framing of Storage → Reflection → Experience

## The Honest Framing

This system is not magic. It will not make an AI feel the weight of a mistake. It cannot replicate what cortisol does to biological neural pathways. What it does is:

1. **Store experiences verbatim and make them findable** (MemPalace)
2. **Rank them by importance so the right ones surface** (FadeMem)
3. **Inject them at the moment of action, not at session start** (hook infrastructure)
4. **Track correction access patterns to identify recurring failures** (outcome tracking)
5. **Escalate the hottest failure modes from advisory to enforcement** (dcg + custom gates)

The behavioral change this produces is probabilistic, not guaranteed. For the cases where "more likely" isn't good enough — destructive operations against shared environments, production deploys, data operations — the enforcement layer physically blocks the action until a human approves out-of-band.

A prosthetic limbic system. Closer than rules in a config file, but not a biological nervous system.

## License

MIT — see [LICENSE](LICENSE).
