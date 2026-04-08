---
description: Evidence base for ABMS — what is true about LLM memory, behavioral persistence, and current infrastructure
tags: [findings, memory, llm, behavioral-change, hooks, context-window]
audience: { human: 60, agent: 40 }
purpose: { findings: 70, research: 20, reference: 10 }
---

# Findings: The Prosthetic Limbic System Problem

## The Core Question

Can an AI coding assistant be given something equivalent to a limbic system — a mechanism that stores experience, determines what matters, surfaces relevant knowledge at the moment of action, and changes behavior from corrections — using existing infrastructure and open-source tools?

## Answer

Partially. Recall (finding stored information) is a solved problem — multiple systems achieve 95%+ on standard benchmarks. But behavioral change from experience — the "tell me once" problem — remains unsolved. The gap is not storage, it is encoding (what gets saved), salience (what matters), and injection timing (when it surfaces). The pieces to close this gap exist across separate projects but have not been assembled into a single system.

---

## Finding 1: LLMs Do Not Learn From Conversations

LLMs are stateless between sessions. Every session starts from the same base weights. Nothing that happens during a conversation changes the model's parameters. What appears as "memory" within a session is information sitting in the context window — a fixed-size buffer that is cleared between sessions and periodically compressed (compacted) within sessions.

This is architecturally different from human memory, where experiences physically alter neural pathways through synaptic plasticity. A human who is corrected changes; an LLM that is corrected has the correction in its context window until the window resets.

**Source:** Direct observation of Claude Code behavior across sessions. 📄

## Finding 2: The Context Window Has a U-Shaped Attention Curve

The "lost in the middle" phenomenon (Liu et al., 2023) demonstrates that LLMs recall information at the beginning and end of context well, but degrade significantly for information in the middle. Performance can degrade by up to 39% for information positioned in the middle of long contexts, even for models explicitly designed for long context.

Larger context windows make this worse, not better. A 1M token window does not provide 5x the usable memory of a 200K window — it provides the same strong edges with a deeper trough in the middle.

This has a direct architectural consequence: rules placed at the start of a session (CLAUDE.md, system prompts) degrade in effectiveness as the conversation grows. By the time the rule is needed, it may be in the trough.

**Source:** "Lost in the Middle: How Language Models Use Long Contexts" — Liu et al., 2023, TACL 2024. 📚  
**Source:** "Found in the Middle" — ICLR 2025, proposes Multi-scale Positional Encoding mitigation. 📚  
**Source:** Observed in practice — CLAUDE.md rules are followed early in sessions but drift later. 👤

## Finding 3: System Prompt Instructions Degrade Predictably

"Control Illusion: The Failure of Instruction Hierarchies in Large Language Models" (February 2025) found that:

- System/user prompt separation fails to establish reliable instruction hierarchy
- Models show strong inherent biases toward certain constraint types regardless of priority designation
- A 39% performance drop in multi-turn conversations for instruction following
- **Meta-cognitive instructions are the first to fall** — instructions like "verify before declaring done" that require the model to monitor its own behavior degrade fastest because they compete with trained patterns (task completion, fluency, confidence)

This validates the observed failure mode: the LLM knows the rule exists, can recite it, but does not reliably follow it when the trained completion pattern is strong.

**Source:** "Control Illusion: The Failure of Instruction Hierarchies in LLMs" — arxiv, February 2025. 📚

## Finding 4: Current Infrastructure Addresses Recall, Not Behavior

The following systems are currently deployed:

### Hook Infrastructure

| Hook | Event | Function | Files |
|------|-------|----------|-------|
| `init-project.sh` | SessionStart | Creates `.claude/` structure, template session journal | `.claude/session-journal.md` |
| `worklog-init.sh` | SessionStart | Registers session, cleans stale sessions, assigns SID | `.claude/worklog.md`, `.claude/.sid-*` |
| `session-journal.sh` | PreCompact | Trims journal to 300 lines, preserves newest entries | `.claude/session-journal.md` |
| `git-safety.sh` | PreToolUse (Bash) | Blocks dangerous git ops, warns on multi-session conflicts | Reads `.claude/worklog.md` |
| `verify-gate.sh` | PreToolUse (Bash) | Blocks `git commit` without verification stamp | `.claude/.verified` |
| `post-bash.sh` | PostToolUse (Bash) | Creates verification stamp when tests pass, tracks session time | `.claude/.verified`, `.claude/.session-tracker` |
| `edit-tracker.sh` | PostToolUse (Edit/Write) | Clears verification stamp on file edit, counts edits | `.claude/.verified`, `.claude/.edit-count` |

All hooks use JSON on stdin and produce stdout output that is injected into the LLM's context. The PreToolUse hooks can return `{"decision": "block", "reason": "..."}` to prevent tool execution and inject a reason message.

**Location:** `~/.claude/hooks/`  
**Configuration:** `~/.claude/settings.json` under `hooks` key  
**Source:** Directly observed. 📄

### Memory Systems

| System | Location | Persistence | Injection | Content |
|--------|----------|-------------|-----------|---------|
| Auto-memory | `~/.claude/projects/<id>/memory/*.md` | Permanent | Session start (automatic) | User, feedback, project, reference memories |
| CLAUDE.md | `~/.claude/CLAUDE.md` | Permanent | Session start (automatic) | 20 behavioral rules + protocols |
| Rules files | `~/.claude/rules/*.md` | Permanent | Session start (automatic) | Skills, review patterns, cleanup procedures |
| Session journal | `<project>/.claude/session-journal.md` | Survives compaction | Re-injected after compaction | Current state + chronological log |
| Worklog | `<project>/.claude/worklog.md` | Survives sessions | SessionStart hook, pre-commit advisory | Active sessions, operation log |
| MCP memory | `~/.claude/projects/<id>/memory/` | Permanent | On explicit query | Knowledge graph entities and observations |

The auto-memory system currently contains 4 entries in the home project. Memory writes are manual — the LLM must decide to save, or the user must ask. There is no automatic encoding from conversations.

**Source:** Directly observed. 📄

### Verification Gate

The edit→test→commit chain works as designed:
1. Every file edit clears the `.verified` stamp
2. Running tests and having them pass creates the stamp
3. `git commit` is blocked without a valid stamp (less than 30 minutes old)

This is the most effective behavioral enforcement mechanism in the current system because it operates at the action level — it physically blocks the undesired action rather than relying on the LLM to remember a rule.

**Source:** Directly observed. 📄

### What's Missing

- No automatic encoding from conversations — all memory writes are manual
- No context-specific rule injection — all rules load at session start regardless of what work is being done
- No correction tracking — when the user corrects behavior, the correction is not stored or surfaced later
- No outcome logging — no record of what actions succeeded or failed
- No salience system — all rules have equal weight regardless of how often they're needed
- No point-of-action injection — rules sit in the primacy zone and degrade; they are not re-surfaced at the moment they would be useful

## Finding 5: Recall Is a Solved Problem

Multiple systems achieve 95%+ on the LongMemEval benchmark (500 questions, 115K+ token conversation histories):

| System | LongMemEval R@5 | Approach | Cost |
|--------|-----------------|----------|------|
| MemPalace (hybrid + rerank) | 100% (disputed — held-out: 98.4%) | Verbatim ChromaDB + LLM rerank | Free/local |
| Supermemory ASMR | ~99% (experimental) | Parallel LLM agents reading raw history | Paid API |
| MemPalace (raw) | 96.6% (independently reproduced) | Verbatim ChromaDB, zero API calls | Free/local |
| agentmemory | 96.2% | Built solo in 16 days | Free/local |
| Mastra | 94.87% | GPT-based extraction | API costs |
| Mem0 | ~85% | Extract-and-summarize | Free–$249/mo |
| Zep | ~85% | Temporal knowledge graph (Graphiti) | $25/mo+ |

The MemPalace 96.6% raw score is notable because it requires no API calls, no cloud, and no LLM at any stage — purely local ChromaDB vector search with spatial indexing (wings, rooms, halls).

**Source:** MemPalace benchmarks (independently reproduced by @gizmax). 📚  
**Source:** Supermemory research blog. 📚  
**Source:** DEV Community comparison article, 2026. 📚

## Finding 6: Biologically-Inspired Forgetting Improves Performance

FadeMem (January 2026) implements Ebbinghaus-inspired adaptive forgetting:

**Decay function:**
```
v(t) = v(0) · exp(-λ · (t - τ)^β)
```

Where λ is adaptive: `λ = λ_base · exp(-μ · I(t))`

**Importance score (salience proxy):**
```
I(t) = α · semantic_relevance + β · access_frequency + γ · recency
```

Key results:
- 45% storage reduction while improving multi-hop reasoning
- Memories promoted to Long-Term Memory (importance ≥ 0.7) decay slowly (β=0.8)
- Memories demoted to Short-Term Memory (importance < 0.3) decay rapidly (β=1.2)
- LLM-guided conflict resolution classifies new memories as compatible, contradictory, subsumes, or subsumed
- Contradictory memories suppress older versions exponentially weighted by age

The insight: **forgetting is not a failure — it is a feature.** Human memory does not keep everything; it decays differentially based on access frequency, relevance, and recency. Systems that keep everything perform worse than systems that forget the right things.

**Source:** "FadeMem: Biologically-Inspired Forgetting for Efficient Agent Memory" — arxiv 2601.18642, January 2026. 📚

## Finding 7: MemPalace Provides Verbatim Storage With Spatial Indexing

MemPalace (launched April 5, 2026) stores conversation data verbatim in ChromaDB and organizes it spatially:

- **Wings** — people, projects, topics (top-level partitions)
- **Rooms** — specific subjects within a wing
- **Halls** — memory type corridors (facts, events, discoveries, preferences, advice)
- **Tunnels** — cross-references between rooms in different wings
- **Closets** — summaries pointing to original content
- **Drawers** — verbatim original files

Retrieval improvement from spatial indexing:
```
Flat search:           60.9% R@10
Wing filter:           73.1% (+12%)
Wing + hall:           84.8% (+24%)
Wing + room:           94.8% (+34%)
```

**Auto-save hooks:**
- `Stop` hook fires every 15 human messages, blocks the LLM, and instructs it to save structured memories
- `PreCompact` hook always fires before compaction, forcing a comprehensive save

**MCP server:** 19 tools (search, add, delete, KG query/add/invalidate, taxonomy, navigation, agent diary)

**Knowledge graph:** SQLite-backed temporal entity-relationship triples with validity windows.

**Source:** MemPalace README, mcp_server.py, hook scripts — directly observed. 📄

## Finding 8: The Research Community Is Organizing Around This Problem

The ICLR 2026 MemAgents Workshop (April 26-27, 2026) is dedicated to "Memory for LLM-Based Agentic Systems." Key framing:

> "The limiting factor is increasingly not raw model capability but memory: how agents encode, retain, retrieve, and consolidate experience into useful knowledge for future decisions."

The survey "Memory in the Age of AI Agents" (December 2025, updated January 2026) proposes a taxonomy:

- **Forms:** token-level (in context), parametric (in weights), latent (learned representations)
- **Functions:** factual (what happened), experiential (what worked), working (what's active now)
- **Dynamics:** formation (encoding), evolution (consolidation + forgetting), retrieval (access)

The evolution they trace: **Storage → Reflection → Experience.** Most current systems are at Storage. The frontier is Experience — memory that changes behavior.

**Source:** ICLR 2026 MemAgents Workshop proposal. 📚  
**Source:** "Memory in the Age of AI Agents: A Survey" — arxiv 2512.13564. 📚

## Finding 9: Neuroscience-Inspired Architectures Are Emerging

Three systems model the full memory lifecycle with biological parallels:

**HEMA** (April 2025) — Hippocampus-inspired dual memory:
- Compact Memory (continuously updated summaries) + Vector Memory (episodic chunk embeddings)
- Factual recall: 41% → 87% on a 6B model across 300+ turns
- Coherence: 2.7 → 4.3 on a 5-point scale

**ZenBrain** (April 2026) — 7-layer architecture with 12 neuroscience algorithms:
- FSRS-based spaced repetition
- Hebbian learning for knowledge graphs
- Hippocampal replay simulation (consolidation during idle)
- Emotional memory modulation
- Bayesian confidence propagation
- In production with 9,228 passing tests

**SuperLocalMemory V3.3** (April 2026) — Cognitive quantization:
- Ebbinghaus adaptive forgetting with lifecycle-aware quantization
- Fading memories literally lose precision (like biological memories becoming vaguer)
- Fisher-Rao distance metric: 100% precision at distinguishing high-fidelity vs quantized embeddings

**Source:** HEMA — arxiv 2504.16754. 📚  
**Source:** ZenBrain — Technical Disclosure Commons. 📚  
**Source:** SuperLocalMemory V3.3 — arxiv 2604.04514. 📚

## Finding 10: Anthropic Shipped Claude Memory (Recall, Not Behavior)

Anthropic rolled out persistent memory for Claude in phases through 2025-2026:

- September 2025: Claude Memory introduced (Team/Enterprise)
- October 2025: Expanded to Pro/Max subscribers
- March 2026: Available to all tiers including free

Features: Memory summary synthesized from conversations, categorized into Role & Work, Current Projects, Personal Content. Editable, deletable.

API Memory Tool (`memory_20250818`): programmatic CRUD for developers — create, read, update, delete memory entries scoped to users, sessions, or application-wide.

This solves recall across sessions on the web/app. It does not solve behavioral change — storing "user prefers Postgres" does not prevent the LLM from recommending MongoDB when the trained pattern is strong.

**Source:** Anthropic announcements, MacRumors October 2025, VentureBeat. 📚  
**Source:** Claude API docs — Memory Tool. 📚

## Finding 11: Post-Training Has Evolved But Remains Training-Time Only

The alignment landscape has moved beyond vanilla RLHF:

- GRPO, DAPO, RLVR have replaced RLHF as the dominant post-training stack
- PLUS framework learns per-user preference summaries (25% improvement over standard RLHF)
- Online Iterative RLHF enables continuous adaptation

However, all of these operate at training time, not runtime. A model trained with DPO behaves differently from one trained with RLHF, but neither changes behavior during deployment based on individual user corrections.

The gap between training-time alignment and runtime behavioral adaptation remains open.

**Source:** "Post-Training in 2026: GRPO, DAPO, RLVR & Beyond" — llm-stats.com. 📚  
**Source:** PLUS framework — OpenReview. 📚

---

## Summary

| What | Status |
|------|--------|
| Storing information across sessions | **Solved** (multiple systems, 95%+) |
| Retrieving relevant information | **Solved** (semantic search + spatial indexing) |
| Forgetting the right things | **Emerging** (FadeMem, SuperLocalMemory) |
| Injecting rules at session start | **Deployed** (CLAUDE.md, auto-memory) |
| Injecting rules at point of action | **Not deployed** (hooks exist but don't carry rules) |
| Tracking behavioral outcomes | **Not deployed** |
| Changing behavior from corrections | **Not solved by any deployed system** |
| Automatic encoding from conversations | **Partially solved** (MemPalace auto-save hooks) |

The critical gap: no system connects correction storage (what went wrong) to action interception (what's about to happen) with salience scoring (is this correction relevant right now). The infrastructure to do this exists across separate systems: MemPalace for storage and search, FadeMem for salience, Claude Code hooks for action interception. They have not been combined.
