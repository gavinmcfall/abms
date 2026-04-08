---
description: All research papers, products, and benchmarks cited in the ABMS declaration chain
tags: [reference, research, sources, citations]
audience: { human: 80, agent: 20 }
purpose: { reference: 100 }
---

# Research Sources

All sources cited in the ABMS declaration chain, organized by topic.

---

## The Lost-in-the-Middle Problem

- **"Lost in the Middle: How Language Models Use Long Contexts"** — Liu et al., 2023. TACL 2024.  
  [arxiv.org/abs/2307.03172](https://arxiv.org/abs/2307.03172)  
  Foundational paper on U-shaped attention in long context. Performance degrades for information in the middle.

- **"Found in the Middle: How Language Models Use Long Contexts Better via Plug-and-Play Positional Encoding"** — ICLR 2025.  
  [openreview.net/forum?id=fPmScVB1Td](https://openreview.net/forum?id=fPmScVB1Td)  
  Multi-scale Positional Encoding (Ms-PoE) mitigation.

## Instruction Following Failure

- **"Control Illusion: The Failure of Instruction Hierarchies in Large Language Models"** — February 2025.  
  [arxiv.org/html/2502.15851v1](https://arxiv.org/html/2502.15851v1)  
  System/user prompt separation fails. Meta-cognitive instructions degrade first. 39% performance drop in multi-turn conversations.

## Memory Products

- **MemPalace** — Milla Jovovich & Ben Sigman. Launched April 5, 2026. 20K+ GitHub stars.  
  [github.com/milla-jovovich/mempalace](https://github.com/milla-jovovich/mempalace)  
  Verbatim ChromaDB storage + spatial indexing (wings/rooms/halls). 96.6% LongMemEval R@5 (raw mode). MCP server with 19 tools. Auto-save hooks. SQLite knowledge graph.

- **Mem0** — 48K GitHub stars, $24M funding.  
  [github.com/mem0ai/mem0](https://github.com/mem0ai/mem0)  
  Extract-and-summarize memory layer. ~85% LongMemEval. Free–$249/mo.

- **Zep (Graphiti)** — Temporal knowledge graph.  
  [getzep.com](https://www.getzep.com/)  
  Episodic and temporal memory. Cloud-hosted or self-hosted. $25/mo+.

- **Letta (formerly MemGPT)** — Full agent runtime with memory as OS primitive.  
  [github.com/letta-ai/letta](https://github.com/letta-ai/letta)  
  Stateful agents with editable memory blocks. PostgreSQL-backed.

- **Supermemory ASMR** — Agentic Search and Memory Retrieval.  
  [supermemory.ai/research](https://supermemory.ai/research/)  
  Parallel LLM agents reading raw history. ~99% LongMemEval (experimental). Paid API.

- **agentmemory** — JordanMcCann. 96.2% LongMemEval. Built in 16 days for $1,000.  
  [github.com/JordanMcCann/agentmemory](https://github.com/JordanMcCann/agentmemory)

- **"5 AI Agent Memory Systems Compared"** — DEV Community, 2026.  
  [dev.to comparison article](https://dev.to/varun_pratapbhardwaj_b13/5-ai-agent-memory-systems-compared-mem0-zep-letta-supermemory-superlocalmemory-2026-benchmark-59p3)

## Biologically-Inspired Memory

- **FadeMem: Biologically-Inspired Forgetting for Efficient Agent Memory** — January 2026.  
  [arxiv.org/abs/2601.18642](https://arxiv.org/abs/2601.18642)  
  Ebbinghaus-inspired adaptive forgetting. Dual-layer memory with importance scoring. 45% storage reduction with improved reasoning.

- **HEMA: A Hippocampus-Inspired Extended Memory Architecture for Long-Context AI Conversations** — April 2025.  
  [arxiv.org/abs/2504.16754](https://arxiv.org/abs/2504.16754)  
  Compact Memory + Vector Memory. Factual recall 41%→87%. Coherence 2.7→4.3.

- **ZenBrain: A Neuroscience-Inspired 7-Layer Memory Architecture for Autonomous AI Systems** — April 2026.  
  [tdcommons.org/dpubs_series/9683](https://www.tdcommons.org/dpubs_series/9683/)  
  12 neuroscience algorithms including emotional memory modulation and hippocampal replay. 9,228 tests.

- **SuperLocalMemory V3.3** — April 2026.  
  [arxiv.org/abs/2604.04514](https://arxiv.org/abs/2604.04514)  
  Cognitive quantization. Ebbinghaus adaptive forgetting with lifecycle-aware quantization.

## Surveys and Workshops

- **"Memory in the Age of AI Agents: A Survey"** — December 2025, updated January 2026.  
  [arxiv.org/abs/2512.13564](https://arxiv.org/abs/2512.13564)  
  Taxonomy: forms (token/parametric/latent), functions (factual/experiential/working), dynamics (formation/evolution/retrieval). Storage→Reflection→Experience evolution.

- **ICLR 2026 MemAgents Workshop** — April 26-27, 2026.  
  [sites.google.com/view/memagent-iclr26](https://sites.google.com/view/memagent-iclr26/)  
  Dedicated workshop on memory for LLM-based agentic systems.

- **"From Storage to Experience: A Survey on the Evolution of LLM Agent Memory Mechanisms"** — ICLR 2026 MemAgents Workshop.  
  [openreview.net/forum?id=l9Ly41xxPb](https://openreview.net/forum?id=l9Ly41xxPb)

- **Awesome-AI-Memory paper list**  
  [github.com/IAAR-Shanghai/Awesome-AI-Memory](https://github.com/IAAR-Shanghai/Awesome-AI-Memory)

## Alignment and Post-Training

- **"Post-Training in 2026: GRPO, DAPO, RLVR & Beyond"**  
  [llm-stats.com/blog/research/post-training-techniques-2026](https://llm-stats.com/blog/research/post-training-techniques-2026)

- **PLUS: Preference Learning Using Summarization** — 25% improvement over standard personalized RLHF.  
  [openreview.net/forum?id=Ar078WR3um](https://openreview.net/forum?id=Ar078WR3um)

## Anthropic Claude Memory

- **Claude Memory announcement** — Anthropic, September 2025.  
  [macrumors.com](https://www.macrumors.com/2025/10/23/anthropic-automatic-memory-claude/)

- **Claude API Memory Tool** — type `memory_20250818`.  
  [platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)

## MCP Memory Servers (Community)

- **mcp-memory-keeper** — [github.com/mkreyman/mcp-memory-keeper](https://github.com/mkreyman/mcp-memory-keeper)
- **mcp-memory-service** — [github.com/doobidoo/mcp-memory-service](https://github.com/doobidoo/mcp-memory-service)
- **ogham-mcp** — Shared memory, 91.8% QA accuracy. [github.com/ogham-mcp/ogham-mcp](https://github.com/ogham-mcp/ogham-mcp)
- **claude-memory-mcp** — [github.com/WhenMoon-afk/claude-memory-mcp](https://github.com/WhenMoon-afk/claude-memory-mcp)
