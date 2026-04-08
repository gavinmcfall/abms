---
description: Testable outcome declarations for ABMS — what should be true when the prosthetic limbic system works
tags: [north-star, outcomes, behavioral-memory, limbic, verification]
audience: { human: 70, agent: 30 }
purpose: { north-star: 90, design: 10 }
---

# North Star: Adaptive Behavioral Memory System

## The Outcome

An AI coding assistant with a prosthetic limbic system — a system that stores experience, determines what matters, surfaces relevant knowledge at the moment of action, and changes behavior from corrections without the user restating them.

Not a smarter filing system. A system that makes the AI behave as if it remembers.

---

## Declarations

### Memory: Nothing Is Lost

**NS-1:** Every conversation the AI has shall be stored verbatim and retrievable by semantic search. The AI shall not depend on summaries or extractions that discard the reasoning, context, and nuance of the original exchange.

**NS-2:** Stored memories shall be organized spatially — by project, person, and topic — so that retrieval narrows to the relevant domain before searching. Structure shall improve retrieval over flat search.

**NS-3:** The AI shall have access to a temporal knowledge graph tracking facts with validity windows. Facts that stop being true shall be invalidated, not deleted, so historical queries remain accurate.

### Salience: Not Everything Matters Equally

**NS-4:** Memories and corrections shall be scored by importance, combining semantic relevance to the current action, frequency of past access, and recency. High-importance items surface; low-importance items fade.

**NS-5:** Forgetting shall be a feature, not a failure. Memories that are never accessed shall decay in retrieval priority. Memories that are repeatedly accessed shall be reinforced. The system shall naturally converge on what matters without manual curation.

**NS-6:** Corrections — records of behavioral failures — shall receive a salience boost over general memories, reflecting that learning from mistakes is higher-value than recalling routine facts.

### Injection: The Right Knowledge at the Right Moment

**NS-7:** When the AI is about to take an action, relevant rules, corrections, and memories shall be surfaced in the recency zone of the context window — not at session start where they degrade over long conversations.

**NS-8:** The rules surfaced shall be specific to the type of work being performed. API work checks response bodies and edge cases. UI work checks visual output at multiple viewports. Data work checks actual values. The system shall determine work context automatically from observable signals (tool name, file path, command pattern, worklog scope).

**NS-9:** Shallow verification patterns — checking only that a request returned 200, that a page rendered, or that tests passed without examining what the tests assert — shall be identified and challenged by the injected rules.

### Behavioral Persistence: Tell Me Once

**NS-10:** A correction given in session N shall influence the AI's behavior in session N+1 without being restated by the user.

**NS-11:** When the AI is about to take an action that has previously resulted in a user correction, the relevant correction shall be surfaced automatically before the action proceeds.

**NS-12:** The system shall track which corrections the AI needed, which it followed, and which it ignored despite being present. This record builds a behavioral profile that informs escalation.

### Self-Improvement: The System Gets Smarter

**NS-13:** Every user correction shall be capturable as a tagged file with a defined format, storable without leaving the terminal workflow.

**NS-14:** Corrections that recur — surfaced and relevant to 5 or more distinct actions across multiple sessions — shall be flagged for promotion to permanent rules.

**NS-15:** Corrections that the AI repeatedly fails to follow despite being present shall be candidates for escalation from advisory injection to blocking enforcement (following the pattern of the existing verification gate).

**NS-16:** The correction store shall be searchable by semantic similarity, not just exact tag matching, so that novel situations can surface relevant past corrections even when the tags don't match exactly.

### Automatic Encoding: The AI Saves Without Being Asked

**NS-17:** The system shall automatically trigger memory saves at regular intervals during conversation — not waiting for the user to ask or for compaction to force it.

**NS-18:** Before context compaction, the system shall force a comprehensive save of all topics, decisions, and context from the current session. Nothing that was discussed shall be lost to compaction.

### Practical Constraints

**NS-19:** Phase 1 of the system shall function with zero external dependencies — bash scripts and markdown files only. Semantic search, knowledge graphs, and scoring are additive layers, not requirements.

**NS-20:** The system shall integrate with existing Claude Code hook infrastructure without replacing or conflicting with the current verification gate, session journal, worklog, or git safety hooks.

**NS-21:** A new user shall have a working system within 30 minutes of cloning the repository and following setup instructions.

**NS-22:** All state shall be human-readable files. Every rule injection shall be visible. The user can view, edit, and delete any correction, rule, or configuration without special tooling.

---

## What This Is Not

This system does not modify model weights or fine-tune the LLM. It cannot make the AI *feel* the importance of a correction. It is an external prosthetic — it shifts the odds by surfacing the right information at the right time, repeatedly, and escalating when that isn't enough.

The honest framing: a real limbic system is biological, pre-conscious, and wired into every decision. This is a software approximation that operates at the interface layer between the AI and its tools. It is closer to a conscience than a limbic system — it watches what the AI is about to do and reminds it of what it should know.

But a conscience that fires reliably, at the right moment, with the right context, and that gets stronger from use — that is significantly better than rules in a config file that degrade into the middle of a million-token context window.
