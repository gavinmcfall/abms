# ABMS — Adaptive Behavioral Memory System

An RFC for building a prosthetic limbic system for AI coding assistants.

## The Problem

Large language models have no limbic system. They have no mechanism that decides what matters, no emotional tagging that determines what gets encoded deeply, no subconscious process that fires before a repeated mistake. Every session starts from the same weights. Every correction evaporates when the context window resets.

Memory products solve recall — finding stored information later. Multiple systems now achieve 95%+ on standard benchmarks. But recall is not behavioral change. You can store "always verify before claiming done" in a dozen places and the LLM will still claim things are done without verifying. The instruction sits in context; the trained pattern wins.

In humans, the limbic system bridges this gap. It tags experiences with emotional weight, consolidates memories during sleep, and fires pre-conscious avoidance responses to situations that previously caused pain. A human who gets burned checks the stove before touching it — not because they consciously recall the rule, but because their nervous system changed.

ABMS is a design for building the equivalent in software: a system that stores experiences verbatim, determines what matters through usage patterns, surfaces relevant knowledge at the moment of action (not at session start where it degrades), tracks what works and what doesn't, and lets corrections that keep recurring escalate from advisory to enforced.

## The Components

ABMS integrates four capabilities that exist separately but have not been combined:

**Verbatim storage with spatial indexing** — Store everything the AI discusses, organized by project, person, and topic. Semantic search retrieves relevant memories without requiring exact queries. Based on MemPalace's architecture (ChromaDB + wings/rooms/halls).

**Salience-weighted forgetting** — Not everything matters equally. Memories that are accessed frequently and recently stay strong. Memories that stop being relevant decay — not deleted, but deprioritized. Based on FadeMem's Ebbinghaus-inspired decay functions.

**Point-of-action injection** — Rules and corrections surface in the recency zone of the context window (where attention is strongest) right before the AI acts. Not at session start where they degrade into the middle of context over long conversations. Built on Claude Code's hook infrastructure.

**Outcome tracking and correction lifecycle** — When the AI fails, the failure is captured. When a correction keeps firing, it escalates. When it stops being needed, it fades. The system learns which behavioral patterns are persistent and adapts enforcement accordingly.

## The Documents

This RFC is structured as an outcome-focused declaration chain. Each document builds on the previous, increasing resolution from evidence through outcomes to architecture:

| Document | What It Establishes |
|----------|-------------------|
| [Findings](declaration/00-findings.md) | What is true today — existing infrastructure, research evidence, identified gaps |
| [North Star](declaration/01-north-star.md) | What should be true — testable outcome declarations |
| [Flow: Injection](declaration/02-flow-injection.md) | How knowledge reaches the AI at the moment of action |
| [Flow: Outcomes](declaration/03-flow-outcomes.md) | How results are captured for future learning |
| [Flow: Correction Lifecycle](declaration/04-flow-correction.md) | How corrections are filed, matched, decayed, or promoted |
| [Design](declaration/05-design.md) | Architecture that makes all flows real — components, integration, trade-offs |

Implementation:
- [Install Guide](implementation/INSTALL.md) — Step-by-step setup for Phase 1
- [Rules Engine](implementation/rules-engine/) — Switch router, injection hook, outcome tracking, 9 context rulesets
- [Hooks](implementation/hooks/) — All supporting hooks (verification gate, git safety, session journal, worklog, edit tracking)
- [Settings](implementation/settings-hooks.json) — Complete hook wiring configuration

Reference material:
- [Existing Systems](reference/existing-systems.md) — Complete inventory of Claude Code infrastructure ABMS integrates with
- [Research Sources](reference/research-sources.md) — All papers, products, and benchmarks cited

## Implementation Phases

| Phase | What | Dependencies | Key Outcome |
|-------|------|-------------|-------------|
| **1: Rules Engine** | Switch router, injection hook, outcome tracking, correction files | Bash + markdown only | Context-specific rules injected at point of action |
| **2: Memory** | Verbatim storage, semantic search, knowledge graph, auto-save hooks | Python, ChromaDB | "What have I forgotten?" queries before every action |
| **3: Salience** | Importance scoring, usage-weighted decay, memory ranking | Python | The right memories surface; the noise fades |
| **4: Self-Improving** | Promotion logic, failure pattern detection, enforcement escalation | Phases 1-3 | Corrections graduate to rules; persistent failures become blocks |

Phase 1 is zero-dependency (bash + markdown) and delivers value immediately. Each subsequent phase adds capability without replacing previous phases.

## Research Foundation

This design draws from current work in AI memory systems, biologically-inspired forgetting, and the empirically documented failure modes of LLM instruction following. The findings document covers the evidence in detail; the research sources document provides the full bibliography with citations.

Key influences: MemPalace (verbatim storage + spatial indexing), FadeMem (Ebbinghaus-inspired adaptive decay), the "Control Illusion" research on instruction hierarchy failure, the HEMA hippocampal dual-memory architecture, and the ICLR 2026 MemAgents workshop framing of the Storage-to-Experience evolution in agent memory.

## Status

Phase 1 is implemented and tested. The rules engine, all hooks, context rulesets, and correction tracking are included in `implementation/` and ready to install. The declaration chain provides the full context — the research, the reasoning, and the design — so reviewers understand not just what was built but why.

Phases 2-4 (MemPalace integration, FadeMem scoring, self-improving correction loop) are designed but not yet implemented. Plans (verifiable truth statements) for those phases will follow.

## License

MIT — see [LICENSE](LICENSE).
